using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;

internal static class WotCursorHideCallPatch
{
    private const int PROCESS_VM_OPERATION = 0x0008;
    private const int PROCESS_VM_READ = 0x0010;
    private const int PROCESS_VM_WRITE = 0x0020;
    private const int PROCESS_QUERY_INFORMATION = 0x0400;
    private const int PAGE_EXECUTE_READWRITE = 0x40;

    // Verified cursor-hide branch targets. The patcher intentionally fails closed
    // on other builds if none of these RVAs contain the expected bytes.
    private static readonly byte[] OriginalBytes = { 0x74, 0x09 };
    private static readonly byte[] PatchedBytes = { 0x74, 0x18 };
    private static readonly PatchTarget[] PatchTargets =
    {
        new PatchTarget("WoT 2.3.0.1476 #2555989", 0x3c5663),
        new PatchTarget("WoT 2.2.1.x observed 2026-05-09", 0x3c5633)
    };

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern IntPtr OpenProcess(int desiredAccess, bool inheritHandle, int processId);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool CloseHandle(IntPtr handle);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool ReadProcessMemory(IntPtr process, IntPtr baseAddress, byte[] buffer, UIntPtr size, out UIntPtr bytesRead);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool WriteProcessMemory(IntPtr process, IntPtr baseAddress, byte[] buffer, UIntPtr size, out UIntPtr bytesWritten);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool VirtualProtectEx(IntPtr process, IntPtr address, UIntPtr size, int newProtect, out int oldProtect);

    private sealed class Options
    {
        public string Mode = "status";
        public int? Pid;
    }

    private sealed class PatchTarget
    {
        public readonly string Label;
        public readonly long Rva;

        public PatchTarget(string label, long rva)
        {
            Label = label;
            Rva = rva;
        }
    }

    private sealed class TargetState
    {
        public PatchTarget Target;
        public IntPtr Address;
        public byte[] Current;
    }

    private static int Main(string[] args)
    {
        Options options;
        if (!TryParseArgs(args, out options))
        {
            PrintUsage();
            return 2;
        }

        Process process;
        try
        {
            process = ResolveProcess(options.Pid);
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine(ex.Message);
            return 3;
        }

        ProcessModule module;
        try
        {
            module = process.MainModule;
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine("Cannot read WorldOfTanks main module: " + ex.Message);
            return 4;
        }

        if (module == null)
        {
            Console.Error.WriteLine("Cannot read WorldOfTanks main module.");
            return 4;
        }

        var handle = OpenProcess(PROCESS_QUERY_INFORMATION | PROCESS_VM_OPERATION | PROCESS_VM_READ | PROCESS_VM_WRITE, false, process.Id);
        if (handle == IntPtr.Zero)
        {
            Console.Error.WriteLine("OpenProcess failed: " + Marshal.GetLastWin32Error());
            return 5;
        }

        try
        {
            var states = ReadTargetStates(handle, module.BaseAddress);
            foreach (var state in states)
            {
                Console.WriteLine(
                    "target=WorldOfTanks.exe pid={0} base=0x{1:X} label=\"{2}\" rva=0x{3:X} address=0x{4:X} current={5}",
                    process.Id,
                    module.BaseAddress.ToInt64(),
                    state.Target.Label,
                    state.Target.Rva,
                    state.Address.ToInt64(),
                    Hex(state.Current));
            }

            var selected = SelectTarget(states);

            if (options.Mode == "status")
            {
                PrintStatus(selected);
                return 0;
            }

            if (selected == null)
            {
                Console.WriteLine("status=unknown");
                Console.Error.WriteLine("No known patch target has expected original/patched bytes; refusing to write.");
                Console.Error.WriteLine("Expected original bytes: " + Hex(OriginalBytes));
                Console.Error.WriteLine("Expected patched bytes:  " + Hex(PatchedBytes));
                return options.Mode == "apply" ? 6 : 7;
            }

            if (options.Mode == "apply")
            {
                return Apply(handle, selected);
            }

            return Rollback(handle, selected);
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine(ex.GetType().Name + ": " + ex.Message);
            return 8;
        }
        finally
        {
            CloseHandle(handle);
        }
    }

    private static TargetState[] ReadTargetStates(IntPtr handle, IntPtr baseAddress)
    {
        var states = new TargetState[PatchTargets.Length];
        for (var i = 0; i < PatchTargets.Length; i++)
        {
            var target = PatchTargets[i];
            var address = IntPtr.Add(baseAddress, checked((int)target.Rva));
            states[i] = new TargetState
            {
                Target = target,
                Address = address,
                Current = ReadExact(handle, address, OriginalBytes.Length)
            };
        }
        return states;
    }

    private static TargetState SelectTarget(TargetState[] states)
    {
        foreach (var state in states)
            if (BytesEqual(state.Current, OriginalBytes))
                return state;

        foreach (var state in states)
            if (BytesEqual(state.Current, PatchedBytes))
                return state;

        return null;
    }

    private static int Apply(IntPtr handle, TargetState state)
    {
        if (BytesEqual(state.Current, PatchedBytes))
        {
            Console.WriteLine("status=patched");
            Console.WriteLine("already patched");
            return 0;
        }

        if (!BytesEqual(state.Current, OriginalBytes))
        {
            Console.WriteLine("status=unknown");
            Console.Error.WriteLine("Unexpected bytes; refusing to patch.");
            Console.Error.WriteLine("Expected original bytes: " + Hex(OriginalBytes));
            Console.Error.WriteLine("Expected patched bytes:  " + Hex(PatchedBytes));
            return 6;
        }

        WriteExact(handle, state.Address, PatchedBytes);
        Console.WriteLine("status=patched");
        Console.WriteLine("patched hide branch: label=\"{0}\" rva=0x{1:X} je +0x09 -> je +0x18", state.Target.Label, state.Target.Rva);
        return 0;
    }

    private static int Rollback(IntPtr handle, TargetState state)
    {
        if (BytesEqual(state.Current, OriginalBytes))
        {
            Console.WriteLine("status=original");
            Console.WriteLine("already original");
            return 0;
        }

        if (!BytesEqual(state.Current, PatchedBytes))
        {
            Console.WriteLine("status=unknown");
            Console.Error.WriteLine("Unexpected bytes; refusing to rollback.");
            Console.Error.WriteLine("Expected original bytes: " + Hex(OriginalBytes));
            Console.Error.WriteLine("Expected patched bytes:  " + Hex(PatchedBytes));
            return 7;
        }

        WriteExact(handle, state.Address, OriginalBytes);
        Console.WriteLine("status=original");
        Console.WriteLine("rolled back hide branch patch: label=\"{0}\" rva=0x{1:X}", state.Target.Label, state.Target.Rva);
        return 0;
    }

    private static void PrintStatus(TargetState selected)
    {
        if (selected == null)
        {
            Console.WriteLine("status=unknown");
            return;
        }

        if (BytesEqual(selected.Current, OriginalBytes))
            Console.WriteLine("status=original");
        else if (BytesEqual(selected.Current, PatchedBytes))
            Console.WriteLine("status=patched");
        else
            Console.WriteLine("status=unknown");
    }

    private static Process ResolveProcess(int? pid)
    {
        if (pid.HasValue)
        {
            var process = Process.GetProcessById(pid.Value);
            if (!string.Equals(process.ProcessName, "WorldOfTanks", StringComparison.OrdinalIgnoreCase))
                throw new InvalidOperationException("PID " + pid.Value + " is not WorldOfTanks.exe.");
            return process;
        }

        var processes = Process.GetProcessesByName("WorldOfTanks");
        if (processes.Length == 0)
            throw new InvalidOperationException("WorldOfTanks.exe is not running.");

        return processes
            .OrderByDescending(SafeStartTimeTicks)
            .First();
    }

    private static long SafeStartTimeTicks(Process process)
    {
        try
        {
            return process.StartTime.Ticks;
        }
        catch
        {
            return 0;
        }
    }

    private static bool TryParseArgs(string[] args, out Options options)
    {
        options = new Options();

        var modes = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
        {
            "apply",
            "rollback",
            "status"
        };

        var modeSeen = false;
        for (var i = 0; i < args.Length; i++)
        {
            var arg = args[i];
            if (arg == "-h" || arg == "--help" || arg == "/?")
                return false;

            if (modes.Contains(arg))
            {
                if (modeSeen)
                    return false;
                options.Mode = arg.ToLowerInvariant();
                modeSeen = true;
                continue;
            }

            if (arg == "--pid")
            {
                if (i + 1 >= args.Length)
                    return false;
                int parsed;
                if (!int.TryParse(args[++i], out parsed))
                    return false;
                options.Pid = parsed;
                continue;
            }

            if (arg.StartsWith("--pid=", StringComparison.OrdinalIgnoreCase))
            {
                int parsed;
                if (!int.TryParse(arg.Substring("--pid=".Length), out parsed))
                    return false;
                options.Pid = parsed;
                continue;
            }

            return false;
        }

        return true;
    }

    private static void PrintUsage()
    {
        Console.Error.WriteLine("Usage: WotCursorHideCallPatch.exe [status|apply|rollback] [--pid PID]");
        Console.Error.WriteLine("Default mode is status. Without --pid, the newest WorldOfTanks.exe process is used.");
    }

    private static byte[] ReadExact(IntPtr handle, IntPtr address, int length)
    {
        var buffer = new byte[length];
        UIntPtr read;
        if (!ReadProcessMemory(handle, address, buffer, (UIntPtr)buffer.Length, out read) || read.ToUInt64() != (ulong)buffer.Length)
            throw new InvalidOperationException("ReadProcessMemory failed: " + Marshal.GetLastWin32Error());
        return buffer;
    }

    private static void WriteExact(IntPtr handle, IntPtr address, byte[] bytes)
    {
        int oldProtect;
        if (!VirtualProtectEx(handle, address, (UIntPtr)bytes.Length, PAGE_EXECUTE_READWRITE, out oldProtect))
            throw new InvalidOperationException("VirtualProtectEx RWX failed: " + Marshal.GetLastWin32Error());

        try
        {
            UIntPtr written;
            if (!WriteProcessMemory(handle, address, bytes, (UIntPtr)bytes.Length, out written) || written.ToUInt64() != (ulong)bytes.Length)
                throw new InvalidOperationException("WriteProcessMemory failed: " + Marshal.GetLastWin32Error());
        }
        finally
        {
            int ignored;
            VirtualProtectEx(handle, address, (UIntPtr)bytes.Length, oldProtect, out ignored);
        }
    }

    private static bool BytesEqual(byte[] a, byte[] b)
    {
        if (a.Length != b.Length)
            return false;

        for (var i = 0; i < a.Length; i++)
        {
            if (a[i] != b[i])
                return false;
        }

        return true;
    }

    private static string Hex(byte[] bytes)
    {
        return string.Join(" ", bytes.Select(b => b.ToString("X2")).ToArray());
    }
}
