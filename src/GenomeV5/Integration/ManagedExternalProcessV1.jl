module ManagedExternalProcessV1

using JSON3

export capture, ManagedProcessAck, ManagedProcessError

const _ACK_SCHEMA = "fca-managed-process-ack-v1"
const _ACK_KEYS = Set((
    "schema",
    "session_id",
    "scope_sha256",
    "child_pid",
    "child_creation_time_100ns",
    "parent_pid",
    "parent_creation_time_100ns",
    "monitor_pid",
    "monitor_creation_time_100ns",
    "registration_sequence",
    "handle_duplicated",
    "identity_registered",
    "job_bound",
    "creation_sample_measured",
    "resume_permitted",
    "full_run_resource_complete",
))
const _MANAGED_ENV_KEYS = (
    "FCA_MANAGED_SESSION_ID",
    "FCA_MANAGED_ACK_DIRECTORY",
    "FCA_MANAGED_SCOPE_SHA256",
    "FCA_MANAGED_MONITOR_PID",
    "FCA_MANAGED_MONITOR_CREATE_100NS",
    "FCA_MANAGED_HANDSHAKE_SECONDS",
    "FCA_MANAGED_DEADLINE_TICK64_MS",
)

const _CREATE_UNICODE_ENVIRONMENT = UInt32(0x00000400)
const _EXTENDED_STARTUPINFO_PRESENT = UInt32(0x00080000)
const _PROC_THREAD_ATTRIBUTE_HANDLE_LIST = UInt(0x00020002)
const _STARTF_USESTDHANDLES = UInt32(0x00000100)
const _GENERIC_READ = UInt32(0x80000000)
const _FILE_SHARE_NONE = UInt32(0)
const _OPEN_EXISTING = UInt32(3)
const _FILE_FLAG_OPEN_REPARSE_POINT = UInt32(0x00200000)
const _FILE_FLAG_SEQUENTIAL_SCAN = UInt32(0x08000000)
const _FILE_ATTRIBUTE_DIRECTORY = UInt32(0x00000010)
const _FILE_ATTRIBUTE_REPARSE_POINT = UInt32(0x00000400)
const _INVALID_FILE_ATTRIBUTES = UInt32(0xffffffff)
const _FILE_ATTRIBUTE_TAG_INFO_CLASS = UInt32(9)
const _ACK_MAX_BYTES = 64 * 1024
const _CLOSE_RETRY_MAX = 3
const _FILE_TYPE_UNKNOWN = UInt32(0)
const _PROCESS_QUERY_LIMITED_INFORMATION = UInt32(0x00001000)
const _SYNCHRONIZE = UInt32(0x00100000)
const _WAIT_OBJECT_0 = UInt32(0)
const _WAIT_TIMEOUT = UInt32(0x00000102)
const _WAIT_FAILED = UInt32(0xffffffff)
const _ERROR_FILE_NOT_FOUND = UInt32(2)
const _ERROR_SHARING_VIOLATION = UInt32(32)
const _ERROR_INSUFFICIENT_BUFFER = UInt32(122)
const _DUPLICATE_SAME_ACCESS = UInt32(0x00000002)
const _WINDOWS_VERBATIM_ARGUMENTS = UInt32(1 << 2)
const _CLEANUP_EXIT_CODE = UInt32(0xe0000001)

struct ManagedProcessAck
    schema::String
    session_id::String
    scope_sha256::String
    child_pid::Int
    child_creation_time_100ns::Int64
    parent_pid::Int
    parent_creation_time_100ns::Int64
    monitor_pid::Int
    monitor_creation_time_100ns::Int64
    registration_sequence::Int64
    handle_duplicated::Bool
    identity_registered::Bool
    job_bound::Bool
    creation_sample_measured::Bool
    resume_permitted::Bool
    full_run_resource_complete::Bool
end

struct ManagedProcessError <: Exception
    stage::Symbol
    win32_error::Union{Nothing,UInt32}
    pid::Union{Nothing,Int}
    creation_time_100ns::Union{Nothing,Int64}
    message::String
    cleanup::NamedTuple
end

function Base.showerror(io::IO, err::ManagedProcessError)
    print(io, "Managed external process failed at ", err.stage, ": ", err.message)
    err.win32_error === nothing || print(io, " (Win32 ", err.win32_error, ")")
    err.pid === nothing || print(io, "; pid=", err.pid)
    err.creation_time_100ns === nothing ||
        print(io, "; creation_time_100ns=", err.creation_time_100ns)
    print(io, "; cleanup=", err.cleanup)
end

struct _CaptureFailure <: Exception
    stage::Symbol
    win32_error::Union{Nothing,UInt32}
    message::String
end

function Base.showerror(io::IO, err::_CaptureFailure)
    print(io, err.message)
    err.win32_error === nothing || print(io, " (Win32 ", err.win32_error, ")")
end

struct _FILETIME
    low::UInt32
    high::UInt32
end

struct _PROCESS_INFORMATION
    process::Ptr{Cvoid}
    thread::Ptr{Cvoid}
    process_id::UInt32
    thread_id::UInt32
end

struct _STARTUPINFOW
    cb::UInt32
    reserved::Ptr{UInt16}
    desktop::Ptr{UInt16}
    title::Ptr{UInt16}
    x::UInt32
    y::UInt32
    x_size::UInt32
    y_size::UInt32
    x_count_chars::UInt32
    y_count_chars::UInt32
    fill_attribute::UInt32
    flags::UInt32
    show_window::UInt16
    reserved2_bytes::UInt16
    reserved2::Ptr{UInt8}
    stdin_handle::Ptr{Cvoid}
    stdout_handle::Ptr{Cvoid}
    stderr_handle::Ptr{Cvoid}
end

struct _STARTUPINFOEXW
    startup:: _STARTUPINFOW
    attribute_list::Ptr{Cvoid}
end

struct _FILE_ATTRIBUTE_TAG_INFO
    attributes::UInt32
    reparse_tag::UInt32
end

struct _BY_HANDLE_FILE_INFORMATION
    attributes::UInt32
    creation_time::_FILETIME
    last_access_time::_FILETIME
    last_write_time::_FILETIME
    volume_serial_number::UInt32
    file_size_high::UInt32
    file_size_low::UInt32
    number_of_links::UInt32
    file_index_high::UInt32
    file_index_low::UInt32
end

mutable struct _PendingHandleRecord
    id::UInt64
    capture_id::UInt64
    kind::Symbol
    handle::Ptr{Cvoid}
    witness::Ptr{Cvoid}
    witness_owned::Bool
    identity::Any
    last_error::Union{Nothing,UInt32}
    reason::String
    raw_operations::Tuple
    lease::Any
end

mutable struct _PendingHandleOwner
    lock::ReentrantLock
    next_id::UInt64
    records::Vector{_PendingHandleRecord}
end

const _PENDING_HANDLE_OWNER = _PendingHandleOwner(ReentrantLock(), UInt64(0),
    _PendingHandleRecord[])

mutable struct _State
    stage::Symbol
    capture_id::UInt64
    deadline_tick64_ms::Union{Nothing,UInt64}
    win32_error::Union{Nothing,UInt32}
    pid::Union{Nothing,Int}
    creation_time_100ns::Union{Nothing,Int64}
    thread_id::Union{Nothing,Int}
    thread_creation_time_100ns::Union{Nothing,Int64}
    process_handle::Ptr{Cvoid}
    thread_handle::Ptr{Cvoid}
    create_process_info_acquired::Bool
    process_acquisition_witness::Ptr{Cvoid}
    thread_acquisition_witness::Ptr{Cvoid}
    monitor_handle::Ptr{Cvoid}
    monitor_identity::Any
    ack_handle::Ptr{Cvoid}
    ack_file_identity::Any
    ack_handle_closed::Union{Nothing,Bool}
    stdout_reader::Any
    stderr_reader::Any
    stdout_child::Any
    stderr_child::Any
    inherited_handles::Vector{Ptr{Cvoid}}
    inherited_sources::Vector{Ptr{Cvoid}}
    inherited_source_owned::Vector{Bool}
    inherited_identities::Vector{Any}
    stdout_task::Any
    stderr_task::Any
    process_signaled::Bool
    termination_attempted::Bool
    termination_succeeded::Union{Nothing,Bool}
    wait_signaled::Union{Nothing,Bool}
    process_handle_closed::Union{Nothing,Bool}
    thread_handle_closed::Union{Nothing,Bool}
    monitor_handle_closed::Union{Nothing,Bool}
    stdio_child_handles_closed::Union{Nothing,Bool}
    pipes_closed::Union{Nothing,Bool}
    reader_tasks_done::Union{Nothing,Bool}
    cleanup_errors::Vector{String}
    handle_close_failures::Vector{NamedTuple}
    pending_ids::Vector{UInt64}
end

function _new_capture_id!()
    lock(_PENDING_HANDLE_OWNER.lock) do
        _PENDING_HANDLE_OWNER.next_id == typemax(UInt64) &&
            throw(OverflowError("managed capture identity exhausted"))
        _PENDING_HANDLE_OWNER.next_id += UInt64(1)
        _PENDING_HANDLE_OWNER.next_id
    end
end

function _State()
    _State(:validate, _new_capture_id!(), nothing, nothing, nothing, nothing,
        nothing, nothing, C_NULL, C_NULL, false, C_NULL, C_NULL,
        C_NULL, nothing, C_NULL, nothing,
        nothing, nothing, nothing, nothing, nothing, Ptr{Cvoid}[], Ptr{Cvoid}[], Bool[], Any[],
        nothing, nothing, false, false, nothing, nothing, nothing, nothing,
        nothing, nothing, nothing, nothing, String[], NamedTuple[], UInt64[])
end

function _fail(stage::Symbol, message::AbstractString;
        win32_error::Union{Nothing,UInt32}=nothing)
    throw(_CaptureFailure(stage, win32_error, String(message)))
end

function _check_win32(ok::Integer, stage::Symbol, operation::AbstractString)
    ok != 0 || _fail(stage, operation; win32_error=Base.Libc.GetLastError())
    nothing
end

function _widez(value::AbstractString, stage::Symbol, label::AbstractString)
    text = String(value)
    Base.containsnul(text) && _fail(stage, label * " contains NUL")
    units = transcode(UInt16, text)
    push!(units, UInt16(0))
    units
end

function _handle_pointer(value)
    value isa Ptr{Cvoid} && return value
    Ptr{Cvoid}(reinterpret(UInt, value))
end

function _get_process_times(handle::Ptr{Cvoid}, stage::Symbol)
    created = Ref(_FILETIME(0, 0))
    exited = Ref(_FILETIME(0, 0))
    kernel = Ref(_FILETIME(0, 0))
    user = Ref(_FILETIME(0, 0))
    ok = ccall(:GetProcessTimes, stdcall, Int32,
        (Ptr{Cvoid}, Ref{_FILETIME}, Ref{_FILETIME}, Ref{_FILETIME}, Ref{_FILETIME}),
        handle, created, exited, kernel, user)
    _check_win32(ok, stage, "GetProcessTimes failed")
    bits = (UInt64(created[].high) << 32) | UInt64(created[].low)
    bits > UInt64(typemax(Int64)) && _fail(stage, "FILETIME exceeds Int64 range")
    Int64(bits)
end

function _filetime_value(value::_FILETIME, stage::Symbol)
    bits = (UInt64(value.high) << 32) | UInt64(value.low)
    bits <= UInt64(typemax(Int64)) || _fail(stage, "FILETIME exceeds Int64 range")
    Int64(bits)
end

function _file_identity(handle::Ptr{Cvoid}, stage::Symbol)
    info = Ref(_BY_HANDLE_FILE_INFORMATION(UInt32(0), _FILETIME(0, 0),
        _FILETIME(0, 0), _FILETIME(0, 0), UInt32(0), UInt32(0), UInt32(0),
        UInt32(0), UInt32(0), UInt32(0)))
    ok = ccall(:GetFileInformationByHandle, stdcall, Int32,
        (Ptr{Cvoid}, Ref{_BY_HANDLE_FILE_INFORMATION}), handle, info)
    _check_win32(ok, stage, "GetFileInformationByHandle failed")
    value = info[]
    size = (UInt64(value.file_size_high) << 32) | UInt64(value.file_size_low)
    (kind=:file,
     volume_serial_number=value.volume_serial_number,
     file_index=(UInt64(value.file_index_high) << 32) | UInt64(value.file_index_low),
     creation_time_100ns=_filetime_value(value.creation_time, stage),
     size=size,
     attributes=value.attributes)
end

function _thread_identity(handle::Ptr{Cvoid}, stage::Symbol)
    thread_id = ccall(:GetThreadId, stdcall, UInt32, (Ptr{Cvoid},), handle)
    thread_id != 0 || _fail(stage, "GetThreadId failed"; win32_error=Base.Libc.GetLastError())
    process_id = ccall(:GetProcessIdOfThread, stdcall, UInt32,
        (Ptr{Cvoid},), handle)
    process_id != 0 || _fail(stage, "GetProcessIdOfThread failed";
        win32_error=Base.Libc.GetLastError())
    created = Ref(_FILETIME(0, 0))
    exited = Ref(_FILETIME(0, 0))
    kernel = Ref(_FILETIME(0, 0))
    user = Ref(_FILETIME(0, 0))
    ok = ccall(:GetThreadTimes, stdcall, Int32,
        (Ptr{Cvoid}, Ref{_FILETIME}, Ref{_FILETIME}, Ref{_FILETIME}, Ref{_FILETIME}),
        handle, created, exited, kernel, user)
    _check_win32(ok, stage, "GetThreadTimes failed")
    (kind=:thread, thread_id=Int(thread_id), owner_pid=Int(process_id),
     creation_time_100ns=_filetime_value(created[], stage))
end

function _handle_identity(handle::Ptr{Cvoid}, kind::Symbol, stage::Symbol)
    if kind in (:child_process, :monitor_process)
        pid = ccall(:GetProcessId, stdcall, UInt32, (Ptr{Cvoid},), handle)
        pid != 0 || _fail(stage, "GetProcessId failed"; win32_error=Base.Libc.GetLastError())
        return (kind=:process, pid=Int(pid),
            creation_time_100ns=_get_process_times(handle, stage))
    elseif kind == :child_thread
        return _thread_identity(handle, stage)
    elseif kind == :ack_file
        return _file_identity(handle, stage)
    end
    file_type = ccall(:GetFileType, stdcall, UInt32, (Ptr{Cvoid},), handle)
    file_type != _FILE_TYPE_UNKNOWN ||
        _fail(stage, "GetFileType failed for retained handle";
            win32_error=Base.Libc.GetLastError())
    (kind=kind, file_type=file_type)
end

function _identity_matches(handle::Ptr{Cvoid}, kind::Symbol, identity, stage::Symbol)
    identity === nothing && return false
    try
        isequal(_handle_identity(handle, kind, stage), identity)
    catch
        false
    end
end

function _same_object(left::Ptr{Cvoid}, right::Ptr{Cvoid})
    left == C_NULL && return false
    right == C_NULL && return false
    try
        ccall(:CompareObjectHandles, stdcall, Int32,
            (Ptr{Cvoid}, Ptr{Cvoid}), left, right) != 0
    catch
        false
    end
end

function _handles_match(left::Ptr{Cvoid}, right::Ptr{Cvoid}, kind::Symbol,
        identity, stage::Symbol)
    identity !== nothing && hasproperty(identity, :kind) &&
            identity.kind in (:process, :thread, :file) &&
            return _identity_matches(left, kind, identity, stage) &&
                _identity_matches(right, kind, identity, stage)
    _same_object(left, right)
end

function _duplicate_witness(handle::Ptr{Cvoid})
    duplicate = Ref{Ptr{Cvoid}}(C_NULL)
    current = ccall(:GetCurrentProcess, stdcall, Ptr{Cvoid}, ())
    ok = ccall(:DuplicateHandle, stdcall, Int32,
        (Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}, Ref{Ptr{Cvoid}}, UInt32, Int32, UInt32),
        current, handle, current, duplicate, UInt32(0), 0, _DUPLICATE_SAME_ACCESS)
    ok != 0 ? (duplicate[], nothing) : (C_NULL, UInt32(Base.Libc.GetLastError()))
end

function _remember_pending!(state::_State, kind::Symbol, handle::Ptr{Cvoid},
        witness::Ptr{Cvoid}, witness_owned::Bool, identity, last_error,
        reason::AbstractString; lease=nothing)
    record = lock(_PENDING_HANDLE_OWNER.lock) do
        _PENDING_HANDLE_OWNER.next_id == typemax(UInt64) &&
            throw(OverflowError("pending native handle identity exhausted"))
        _PENDING_HANDLE_OWNER.next_id += UInt64(1)
        tracked_handles = Set{UInt}((UInt(handle),))
        witness == C_NULL || push!(tracked_handles, UInt(witness))
        operations = Tuple(operation for operation in state.handle_close_failures
            if operation.handle in tracked_handles)
        item = _PendingHandleRecord(_PENDING_HANDLE_OWNER.next_id, state.capture_id,
            kind, handle, witness, witness_owned, identity,
            last_error === nothing ? nothing : UInt32(last_error), String(reason),
            operations, lease)
        push!(_PENDING_HANDLE_OWNER.records, item)
        item
    end
    push!(state.pending_ids, record.id)
    record.id
end

function _deadline_allows_retry(state::_State)
    state.deadline_tick64_ms !== nothing &&
        _tick64_ms() < state.deadline_tick64_ms
end

function _retry_pause!(state::_State)
    _deadline_allows_retry(state) || return false
    yield()
    _deadline_allows_retry(state) || return false
    sleep(0.001)
    _deadline_allows_retry(state)
end

function _close_final_handle!(state::_State, handle::Ptr{Cvoid}, kind::Symbol,
        identity, label::String)
    retries = kind in (:stdio, :capture_pipe) ? 1 : _CLOSE_RETRY_MAX
    last_error = nothing
    for attempt in 1:retries
        if !_identity_matches(handle, kind, identity, :cleanup_identity)
            message = label * ": final handle identity could not be confirmed"
            _remember_pending!(state, kind, handle, C_NULL, false, identity,
                last_error, message)
            push!(state.cleanup_errors, message)
            return false
        end
        ok = ccall(:CloseHandle, stdcall, Int32, (Ptr{Cvoid},), handle)
        ok != 0 && return true
        last_error = UInt32(Base.Libc.GetLastError())
        push!(state.handle_close_failures,
            (kind=kind, handle=UInt(handle), attempt=attempt, error=last_error, identity=identity))
        (attempt == retries || !_retry_pause!(state)) && break
    end
    message = label * ": final CloseHandle remained unconfirmed"
    _remember_pending!(state, kind, handle, C_NULL, false, identity, last_error, message)
    push!(state.cleanup_errors, message)
    false
end

function _close_witness!(state::_State, witness::Ptr{Cvoid}, kind::Symbol,
        identity, label::String)
    witness == C_NULL && return true
    peer, duplicate_error = _duplicate_witness(witness)
    if peer == C_NULL
        message = label * ": no independent witness available to close retained handle safely"
        _remember_pending!(state, kind, witness, C_NULL, false, identity,
            duplicate_error, message)
        push!(state.cleanup_errors, message)
        return false
    end
    if !_handles_match(witness, peer, kind, identity, :cleanup_identity) ||
            !_identity_matches(witness, kind, identity, :cleanup_identity)
        message = label * ": witness-of-witness identity did not match"
        _remember_pending!(state, kind, witness, peer, true, identity, nothing, message)
        push!(state.cleanup_errors, message)
        return false
    end
    last_error = nothing
    for attempt in 1:_CLOSE_RETRY_MAX
        if !_handles_match(witness, peer, kind, identity, :cleanup_identity) ||
                !_identity_matches(witness, kind, identity, :cleanup_identity)
            message = label * ": handle identity changed after CloseHandle failure"
            _remember_pending!(state, kind, witness, peer, true, identity,
                last_error, message)
            push!(state.cleanup_errors, message)
            return false
        end
        ok = ccall(:CloseHandle, stdcall, Int32, (Ptr{Cvoid},), witness)
        if ok != 0
            return _close_final_handle!(state, peer, kind, identity,
                label * " final identity witness")
        end
        last_error = UInt32(Base.Libc.GetLastError())
        push!(state.handle_close_failures,
            (kind=kind, handle=UInt(witness), attempt=attempt,
             error=last_error, identity=identity))
        (attempt == _CLOSE_RETRY_MAX || !_retry_pause!(state)) && break
    end
    message = label * ": CloseHandle remained unconfirmed"
    _remember_pending!(state, kind, witness, peer, true, identity, last_error, message)
    push!(state.cleanup_errors, message)
    false
end

function _release_owned_handle!(state::_State, handle::Ptr{Cvoid}, kind::Symbol,
        label::String; lease=nothing, expected_identity=nothing)
    handle == C_NULL && return (target_closed=true, ownership_transferred=false,
        complete=true)
    identity = expected_identity
    current_identity = try
        _handle_identity(handle, kind, :cleanup_identity)
    catch err
        message = label * ": could not capture native handle identity: " * sprint(showerror, err)
        push!(state.cleanup_errors, message)
        _remember_pending!(state, kind, handle, C_NULL, false, identity,
            err isa _CaptureFailure ? err.win32_error : nothing, message; lease=lease)
        return (target_closed=false, ownership_transferred=true, complete=false)
    end
    identity === nothing && (identity = current_identity)
    if !isequal(current_identity, identity)
        message = label * ": native handle no longer matches its acquisition identity"
        push!(state.cleanup_errors, message)
        _remember_pending!(state, kind, handle, C_NULL, false, identity, nothing,
            message; lease=lease)
        return (target_closed=false, ownership_transferred=true, complete=false)
    end
    witness, duplicate_error = _duplicate_witness(handle)
    if witness == C_NULL
        message = label * ": could not retain identity witness for native handle"
        push!(state.cleanup_errors, message)
        push!(state.handle_close_failures,
            (kind=kind, handle=UInt(handle), attempt=0, error=duplicate_error, identity=identity))
        _remember_pending!(state, kind, handle, C_NULL, false, identity,
            duplicate_error, message; lease=lease)
        return (target_closed=false, ownership_transferred=true, complete=false)
    end
    if !_handles_match(handle, witness, kind, identity, :cleanup_identity) ||
            !_identity_matches(handle, kind, identity, :cleanup_identity)
        message = label * ": native handle identity witness did not match"
        push!(state.cleanup_errors, message)
        _remember_pending!(state, kind, handle, witness, true, identity, nothing,
            message; lease=lease)
        return (target_closed=false, ownership_transferred=true, complete=false)
    end
    for attempt in 1:_CLOSE_RETRY_MAX
        ok = ccall(:CloseHandle, stdcall, Int32, (Ptr{Cvoid},), handle)
        if ok != 0
            witness_closed = _close_witness!(state, witness, kind, identity,
                label * " identity witness")
            return (target_closed=true, ownership_transferred=false,
                complete=witness_closed)
        end
        code = UInt32(Base.Libc.GetLastError())
        push!(state.handle_close_failures,
            (kind=kind, handle=UInt(handle), attempt=attempt, error=code, identity=identity))
        if !_handles_match(handle, witness, kind, identity, :cleanup_identity) ||
                !_identity_matches(handle, kind, identity, :cleanup_identity)
            message = label * ": handle changed after CloseHandle failure"
            push!(state.cleanup_errors, message)
            _remember_pending!(state, kind, handle, witness, true, identity, code,
                message; lease=lease)
            return (target_closed=false, ownership_transferred=true, complete=false)
        end
        if attempt == _CLOSE_RETRY_MAX || !_retry_pause!(state)
            break
        end
    end
    code = isempty(state.handle_close_failures) ? nothing : last(state.handle_close_failures).error
    message = label * ": CloseHandle remained unconfirmed"
    push!(state.cleanup_errors, message)
    _remember_pending!(state, kind, handle, witness, true, identity, code,
        message; lease=lease)
    (target_closed=false, ownership_transferred=true, complete=false)
end

function _retain_active_handle!(state::_State, handle::Ptr{Cvoid}, kind::Symbol,
        label::String; expected_identity=nothing)
    identity = expected_identity
    current_identity = try
        _handle_identity(handle, kind, :cleanup_identity)
    catch err
        message = label * ": could not capture active handle identity: " * sprint(showerror, err)
        push!(state.cleanup_errors, message)
        _remember_pending!(state, kind, handle, C_NULL, false, identity,
            err isa _CaptureFailure ? err.win32_error : nothing, message)
        return false
    end
    identity === nothing && (identity = current_identity)
    if !isequal(current_identity, identity)
        message = label * ": active handle no longer matches its acquisition identity"
        push!(state.cleanup_errors, message)
        _remember_pending!(state, kind, handle, C_NULL, false, identity, nothing, message)
        return false
    end
    witness, duplicate_error = _duplicate_witness(handle)
    if witness == C_NULL
        message = label * ": could not retain active-handle witness"
        push!(state.cleanup_errors, message)
        _remember_pending!(state, kind, handle, C_NULL, false, identity,
            duplicate_error, message)
        return false
    end
    if !_handles_match(handle, witness, kind, identity, :cleanup_identity) ||
            !_identity_matches(handle, kind, identity, :cleanup_identity)
        message = label * ": active-handle identity witness did not match"
        push!(state.cleanup_errors, message)
        _remember_pending!(state, kind, handle, witness, true, identity, nothing, message)
        return false
    end
    _remember_pending!(state, kind, handle, witness, true, identity, nothing,
        label * ": process remains unsignaled at original deadline")
    true
end

_tick64_ms() = ccall(:GetTickCount64, stdcall, UInt64, ())

function _check_phase_deadline(config, stage::Symbol)
    _tick64_ms() < config.deadline_tick64_ms ||
        _fail(stage, "original supervised phase deadline expired")
    nothing
end

function _check_monitor_alive(state::_State, stage::Symbol)
    state.monitor_handle != C_NULL || _fail(stage, "retained monitor handle is absent")
    status = ccall(:WaitForSingleObject, stdcall, UInt32,
        (Ptr{Cvoid}, UInt32), state.monitor_handle, UInt32(0))
    status == _WAIT_TIMEOUT || _fail(stage,
        status == _WAIT_OBJECT_0 ? "managed monitor exited before child completion" :
            "cannot verify managed monitor liveness";
        win32_error=status == _WAIT_FAILED ? Base.Libc.GetLastError() : nothing)
    nothing
end

function _file_attributes(path::AbstractString, stage::Symbol)
    wide = _widez(path, stage, "path")
    value = GC.@preserve wide ccall(:GetFileAttributesW, stdcall, UInt32,
        (Ptr{UInt16},), pointer(wide))
    value == _INVALID_FILE_ATTRIBUTES &&
        _fail(stage, "GetFileAttributesW failed for " * String(path);
            win32_error=Base.Libc.GetLastError())
    value
end

function _safe_ack_directory(raw::AbstractString)
    stage = :ack_directory
    isabspath(raw) || _fail(stage, "FCA_MANAGED_ACK_DIRECTORY must be absolute")
    directory = abspath(normpath(String(raw)))
    isdir(directory) || _fail(stage, "managed ACK directory is absent")
    current = directory
    final_attributes = UInt32(0)
    while true
        attributes = _file_attributes(current, stage)
        (attributes & _FILE_ATTRIBUTE_REPARSE_POINT) == 0 ||
            _fail(stage, "managed ACK path contains a reparse point")
        current == directory && (final_attributes = attributes)
        parent = dirname(current)
        parent == current && break
        current = parent
    end
    (final_attributes & _FILE_ATTRIBUTE_DIRECTORY) != 0 ||
        _fail(stage, "managed ACK path is not a directory")
    directory
end

function _positive_decimal(text::String, label::String, max_value::UInt64,
        stage::Symbol)
    occursin(r"^[0-9]+$", text) || _fail(stage, label * " must be unsigned decimal")
    value = tryparse(UInt64, text)
    value === nothing && _fail(stage, label * " is outside UInt64 range")
    (value > 0 && value <= max_value) ||
        _fail(stage, label * " is outside its positive native range")
    value
end

function _managed_environment()
    stage = :environment
    values = Dict{String,String}()
    for key in _MANAGED_ENV_KEYS
        haskey(ENV, key) || _fail(stage, "missing managed environment key " * key)
        values[key] = String(ENV[key])
    end
    occursin(r"^[0-9a-f]{64}$", values["FCA_MANAGED_SESSION_ID"]) ||
        _fail(stage, "managed session id is not 64 lowercase hexadecimal characters")
    occursin(r"^[0-9a-f]{64}$", values["FCA_MANAGED_SCOPE_SHA256"]) ||
        _fail(stage, "managed scope SHA256 is not 64 lowercase hexadecimal characters")
    monitor_pid_u64 = _positive_decimal(values["FCA_MANAGED_MONITOR_PID"],
        "monitor PID", UInt64(typemax(UInt32)), stage)
    monitor_ticks_u64 = _positive_decimal(values["FCA_MANAGED_MONITOR_CREATE_100NS"],
        "monitor creation time", UInt64(typemax(Int64)), stage)
    handshake = tryparse(Float64, values["FCA_MANAGED_HANDSHAKE_SECONDS"])
    handshake !== nothing && isfinite(handshake) && handshake > 0 ||
        _fail(stage, "handshake seconds must be finite and positive")
    handshake_ns = handshake * 1.0e9
    handshake_ns <= Float64(typemax(UInt64)) ||
        _fail(stage, "handshake deadline exceeds UInt64 range")
    deadline_tick_u64 = _positive_decimal(values["FCA_MANAGED_DEADLINE_TICK64_MS"],
        "absolute phase deadline tick", typemax(UInt64), stage)
    deadline_tick_u64 > _tick64_ms() ||
        _fail(:deadline, "original supervised phase deadline has expired")
    directory = _safe_ack_directory(values["FCA_MANAGED_ACK_DIRECTORY"])
    (session_id=values["FCA_MANAGED_SESSION_ID"],
     scope_sha256=values["FCA_MANAGED_SCOPE_SHA256"],
     ack_directory=directory,
     monitor_pid=Int(monitor_pid_u64),
     monitor_ticks=Int64(monitor_ticks_u64),
     handshake_ns=UInt64(floor(handshake_ns)),
     deadline_tick64_ms=deadline_tick_u64,
     reserved_values=values)
end

function _monitor_handle(config, state::_State)
    state.stage = :monitor_identity
    desired = _PROCESS_QUERY_LIMITED_INFORMATION | _SYNCHRONIZE
    handle = ccall(:OpenProcess, stdcall, Ptr{Cvoid},
        (UInt32, Int32, UInt32), desired, 0, UInt32(config.monitor_pid))
    handle == C_NULL && _fail(:monitor_identity, "OpenProcess(monitor) failed";
        win32_error=Base.Libc.GetLastError())
    state.monitor_handle = handle
    identity = _handle_identity(handle, :monitor_process, :monitor_identity)
    identity.pid == config.monitor_pid && identity.creation_time_100ns == config.monitor_ticks ||
        _fail(:monitor_identity, "monitor PID creation time does not match the monitored environment")
    state.monitor_identity = identity
    status = ccall(:WaitForSingleObject, stdcall, UInt32,
        (Ptr{Cvoid}, UInt32), handle, UInt32(0))
    status == _WAIT_TIMEOUT || _fail(:monitor_identity,
        status == _WAIT_OBJECT_0 ? "managed monitor is not alive" : "cannot query managed monitor liveness";
        win32_error=status == _WAIT_FAILED ? Base.Libc.GetLastError() : nothing)
    handle
end

function _split_environment_entry(entry::String, stage::Symbol)
    try
        Base.splitenv(entry)
    catch
        _fail(stage, "Cmd.env contains a malformed environment entry")
    end
end

function _child_environment(cmd::Cmd, config)
    cmd.env === nothing && return nothing
    stage = :environment
    entries = String[String(x) for x in cmd.env]
    managed_names = Set(Base.winuppercase(k) for k in _MANAGED_ENV_KEYS)
    filter!(entries) do entry
        Base.containsnul(entry) && _fail(stage, "Cmd.env entry contains NUL")
        key, _ = _split_environment_entry(entry, stage)
        !(Base.winuppercase(String(key)) in managed_names)
    end
    append!(entries, String[k * "=" * config.reserved_values[k] for k in _MANAGED_ENV_KEYS])
    sort!(entries; by=entry -> Base.winuppercase(String(first(_split_environment_entry(entry, stage)))),
        alg=Base.Sort.MergeSort)
    block = UInt16[]
    for entry in entries
        append!(block, transcode(UInt16, entry))
        push!(block, UInt16(0))
    end
    push!(block, UInt16(0))
    block
end

function _effective_path(cmd::Cmd, stage::Symbol)
    if cmd.env !== nothing
        found = String[]
        for raw_entry in cmd.env
            entry = String(raw_entry)
            Base.containsnul(entry) && _fail(stage, "Cmd.env entry contains NUL")
            key, value = _split_environment_entry(entry, stage)
            Base.winuppercase(String(key)) == "PATH" && push!(found, String(value))
        end
        length(found) > 1 && _fail(stage, "Cmd.env has duplicate PATH entries")
        !isempty(found) && return only(found)
    end
    String(get(ENV, "PATH", ""))
end

function _candidate_file(path::String, stage::Symbol)
    wide = _widez(path, stage, "application search path")
    attributes = GC.@preserve wide ccall(:GetFileAttributesW, stdcall, UInt32,
        (Ptr{UInt16},), pointer(wide))
    attributes != _INVALID_FILE_ATTRIBUTES &&
        (attributes & _FILE_ATTRIBUTE_DIRECTORY) == 0
end

function _path_join_candidate(directory::String, filename::String,
        extension::String, cwd::String)
    root = cwd
    dir = directory
    dir_chars = collect(dir)
    cwd_chars = collect(cwd)
    if length(dir_chars) > 2 && dir_chars[1] in ('\\', '/') &&
            dir_chars[2] in ('\\', '/')
        root = ""
    elseif !isempty(dir_chars) && dir_chars[1] in ('\\', '/')
        root = length(cwd_chars) >= 2 ? join(cwd_chars[1:2]) : ""
    elseif length(dir_chars) >= 2 && dir_chars[2] == ':' &&
            (length(dir_chars) == 2 || !(dir_chars[3] in ('\\', '/')))
        same_drive = length(cwd_chars) >= 2 &&
            uppercase(join(cwd_chars[1:2])) == uppercase(join(dir_chars[1:2]))
        if same_drive
            root = cwd
            dir = join(dir_chars[3:end])
        else
            root = ""
        end
    elseif length(dir_chars) > 2 && dir_chars[2] == ':'
        root = ""
    end

    result = root
    if !isempty(result) && !(last(result) in ('\\', '/', ':'))
        result *= "\\"
    end
    if !isempty(dir)
        result *= dir
        !(last(dir) in ('\\', '/', ':')) && (result *= "\\")
    end
    result *= filename
    if !isempty(extension)
        result *= last(filename) == '.' ? extension : "." * extension
    end
    result
end

function _path_search_extensions(filename::String)
    dot = findfirst(==('.'), filename)
    has_extension = dot !== nothing && dot < lastindex(filename)
    has_extension ? ("", "com", "exe") : ("com", "exe")
end

function _path_search_walk(directory::String, filename::String, cwd::String, stage::Symbol)
    for extension in _path_search_extensions(filename)
        candidate = _path_join_candidate(directory, filename, extension, cwd)
        _candidate_file(candidate, stage) && return candidate
    end
    nothing
end

function _path_entries(path::String)
    entries = String[]
    isempty(path) && return entries
    index = firstindex(path)
    after_end = nextind(path, lastindex(path))
    while index < after_end
        if path[index] == ';'
            index = nextind(path, index)
            continue
        end
        start = index
        quote_char = path[index] in ('"', '\'') ? path[index] : nothing
        scan_from = quote_char === nothing ? index : nextind(path, index)
        quote_end = quote_char === nothing ? nothing : findnext(==(quote_char), path, scan_from)
        delimiter_from = quote_char !== nothing && quote_end === nothing ? after_end :
            quote_end === nothing ? scan_from : nextind(path, quote_end)
        delimiter = findnext(==(';'), path, delimiter_from)
        stop = delimiter === nothing ? lastindex(path) : prevind(path, delimiter)
        if stop >= start
            entry = String(SubString(path, start, stop))
            if quote_char !== nothing && first(entry) == quote_char
                entry_chars = collect(entry)
                if length(entry_chars) >= 2 && last(entry_chars) == quote_char
                    entry = join(entry_chars[2:end-1])
                else
                    entry = join(entry_chars[2:end])
                end
            end
            isempty(entry) || push!(entries, entry)
        end
        index = delimiter === nothing ? after_end : nextind(path, delimiter)
    end
    entries
end

function _resolve_application(file::String, cwd::String, path::String, stage::Symbol)
    is_path_component(character) = character in ('\\', '/', ':')
    delimiter = findlast(is_path_component, file)
    has_directory = delimiter !== nothing
    directory = has_directory ? String(SubString(file, firstindex(file), delimiter)) : ""
    filename = has_directory ?
        String(SubString(file, nextind(file, delimiter))) : file
    isempty(filename) && _fail(stage, "application filename is empty")
    if has_directory
        candidate = _path_search_walk(directory, filename, cwd, stage)
        candidate === nothing && _fail(stage, "application path was not found by Cmd search semantics";
            win32_error=_ERROR_FILE_NOT_FOUND)
        return candidate
    end
    candidate = _path_search_walk("", filename, cwd, stage)
    candidate === nothing || return candidate
    for path_directory in _path_entries(path)
        candidate = _path_search_walk(path_directory, filename, cwd, stage)
        candidate === nothing || return candidate
    end
    _fail(stage, "application name was not found on the effective Cmd PATH";
        win32_error=_ERROR_FILE_NOT_FOUND)
end

function _command_parts(command::Cmd)
    stage = :command
    isempty(command.exec) && _fail(stage, "cannot spawn an empty command")
    exec = String[String(x) for x in command.exec]
    foreach(x -> Base.containsnul(x) && _fail(stage, "Cmd argument contains NUL"), exec)
    unsupported_flags = command.flags & ~_WINDOWS_VERBATIM_ARGUMENTS
    unsupported_flags == 0 ||
        _fail(stage, "managed client does not silently reinterpret detach/hide flags")
    command.cpus === nothing ||
        _fail(stage, "managed client cannot preserve Cmd CPU-affinity semantics")
    commandline = (command.flags & _WINDOWS_VERBATIM_ARGUMENTS) != 0 ?
        join(exec, " ") : Base.escape_microsoft_c_args(exec...)
    working_directory = isempty(command.dir) ? pwd() : String(command.dir)
    application_path = _resolve_application(first(exec), working_directory,
        _effective_path(command, stage), stage)
    application = _widez(application_path, stage, "resolved application path")
    mutable_commandline = _widez(commandline, stage, "command line")
    directory = isempty(command.dir) ? nothing : _widez(command.dir, stage, "working directory")
    (application=application, commandline=mutable_commandline, directory=directory)
end

function _duplicate_inheritable(handle::Ptr{Cvoid}, state::_State, stage::Symbol,
        source_owned::Bool)
    source_identity = _handle_identity(handle, :stdio, stage)
    target = Ref{Ptr{Cvoid}}(C_NULL)
    current = ccall(:GetCurrentProcess, stdcall, Ptr{Cvoid}, ())
    ok = ccall(:DuplicateHandle, stdcall, Int32,
        (Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}, Ref{Ptr{Cvoid}}, UInt32, Int32, UInt32),
        current, handle, current, target, UInt32(0), 1, _DUPLICATE_SAME_ACCESS)
    ok != 0 || _fail(stage, "DuplicateHandle(inheritable stdio) failed";
        win32_error=Base.Libc.GetLastError())
    push!(state.inherited_handles, target[])
    push!(state.inherited_sources, handle)
    push!(state.inherited_source_owned, source_owned)
    push!(state.inherited_identities, source_identity)
    _handles_match(handle, target[], :stdio, source_identity, stage) &&
            _identity_matches(target[], :stdio, source_identity, stage) ||
        _fail(stage, "inherited stdio duplicate identity does not match its source")
    target[]
end

function _close_stdio_source!(state::_State, field::Symbol, label::String;
        expected_identity=nothing)
    source = getfield(state, field)
    source === nothing && return true
    handle = try
        _handle_pointer(Base.rawhandle(source))
    catch err
        message = label * ": cannot obtain source handle: " * sprint(showerror, err)
        push!(state.cleanup_errors, message)
        _remember_pending!(state, :stdio_source, C_NULL, C_NULL, false, nothing,
            nothing, message; lease=source)
        setfield!(state, field, nothing)
        return false
    end
    identity = expected_identity
    current_identity = try
        _handle_identity(handle, :stdio, :stdio_cleanup)
    catch err
        message = label * ": cannot identify source handle: " * sprint(showerror, err)
        push!(state.cleanup_errors, message)
        _remember_pending!(state, :stdio_source, handle, C_NULL, false, nothing,
            err isa _CaptureFailure ? err.win32_error : nothing, message; lease=source)
        setfield!(state, field, nothing)
        return false
    end
    identity === nothing && (identity = current_identity)
    if !isequal(current_identity, identity)
        message = label * ": source handle no longer matches its acquisition identity"
        push!(state.cleanup_errors, message)
        _remember_pending!(state, :stdio_source, handle, C_NULL, false, identity,
            nothing, message; lease=source)
        setfield!(state, field, nothing)
        return false
    end
    witness, duplicate_error = _duplicate_witness(handle)
    if witness == C_NULL
        message = label * ": cannot retain source handle witness"
        push!(state.cleanup_errors, message)
        _remember_pending!(state, :stdio_source, handle, C_NULL, false, identity,
            duplicate_error, message; lease=source)
        setfield!(state, field, nothing)
        return false
    end
    if !_handles_match(handle, witness, :stdio, identity, :stdio_cleanup) ||
            !_identity_matches(handle, :stdio, identity, :stdio_cleanup)
        message = label * ": source identity witness does not match"
        push!(state.cleanup_errors, message)
        _remember_pending!(state, :stdio_source, handle, witness, true, identity, nothing,
            message; lease=source)
        setfield!(state, field, nothing)
        return false
    end
    try
        Base.close_stdio(source)
        setfield!(state, field, nothing)
        _close_witness!(state, witness, :stdio, identity, label * " identity witness")
    catch err
        message = label * ": close failed: " * sprint(showerror, err)
        push!(state.cleanup_errors, message)
        _remember_pending!(state, :stdio_source, handle, witness, true, identity, nothing,
            message; lease=source)
        setfield!(state, field, nothing)
        false
    end
end

function _init_attribute_list(handles::Vector{Ptr{Cvoid}}, state::_State)
    stage = :startup_attributes
    required = Ref{Csize_t}(0)
    first_ok = ccall(:InitializeProcThreadAttributeList, stdcall, Int32,
        (Ptr{Cvoid}, UInt32, UInt32, Ref{Csize_t}),
        C_NULL, UInt32(1), UInt32(0), required)
    (!iszero(first_ok) || Base.Libc.GetLastError() == _ERROR_INSUFFICIENT_BUFFER) ||
        _fail(stage, "InitializeProcThreadAttributeList size query failed";
            win32_error=Base.Libc.GetLastError())
    required[] > 0 || _fail(stage, "attribute-list size query returned zero")
    buffer = Vector{UInt8}(undef, Int(required[]))
    list = Ptr{Cvoid}(pointer(buffer))
    ok = GC.@preserve buffer ccall(:InitializeProcThreadAttributeList, stdcall, Int32,
        (Ptr{Cvoid}, UInt32, UInt32, Ref{Csize_t}),
        list, UInt32(1), UInt32(0), required)
    _check_win32(ok, stage, "InitializeProcThreadAttributeList failed")
    try
        ok = GC.@preserve buffer handles ccall(:UpdateProcThreadAttribute, stdcall, Int32,
            (Ptr{Cvoid}, UInt32, UInt, Ptr{Cvoid}, Csize_t, Ptr{Cvoid}, Ptr{Csize_t}),
            list, UInt32(0), _PROC_THREAD_ATTRIBUTE_HANDLE_LIST,
            pointer(handles), Csize_t(length(handles) * sizeof(Ptr{Cvoid})), C_NULL, C_NULL)
        _check_win32(ok, stage, "UpdateProcThreadAttribute(handle list) failed")
    catch
        ccall(:DeleteProcThreadAttributeList, stdcall, Cvoid, (Ptr{Cvoid},), list)
        rethrow()
    end
    (buffer=buffer, list=list)
end

function _create_debug_event_gated(command::Cmd, config, state::_State)
    state.stage = :debugger_gate
    ccall(:IsDebuggerPresent, stdcall, Int32, ()) != 0 ||
        _fail(:debugger_gate,
            "managed child requires an inherited DEBUG_PROCESS monitor")

    state.stage = :stdio_setup
    stdout_reader = Base.PipeEndpoint()
    stderr_reader = Base.PipeEndpoint()
    stdout_child, close_stdout_child = Base.setup_stdio(stdout_reader, false)
    state.stdout_reader = stdout_reader
    state.stdout_child = close_stdout_child ? stdout_child : nothing
    stderr_child, close_stderr_child = Base.setup_stdio(stderr_reader, false)
    state.stderr_reader = stderr_reader
    state.stderr_child = close_stderr_child ? stderr_child : nothing

    stdin_handle = _handle_pointer(Base.rawhandle(Base.RawFD(0)))
    stdin_handle == C_NULL && _fail(:stdio_setup, "Base stdin handle is null")
    stdout_handle = _handle_pointer(stdout_child)
    stderr_handle = _handle_pointer(stderr_child)

    inherited = Ptr{Cvoid}[
        _duplicate_inheritable(stdin_handle, state, :stdio_setup, false),
        _duplicate_inheritable(stdout_handle, state, :stdio_setup, close_stdout_child),
        _duplicate_inheritable(stderr_handle, state, :stdio_setup, close_stderr_child),
    ]
    length(unique(inherited)) == 3 ||
        _fail(:stdio_setup, "restricted stdio handle list contains duplicates")

    parts = _command_parts(command)
    envblock = _child_environment(command, config)
    cwd = parts.directory
    startup_base = _STARTUPINFOW(
        UInt32(sizeof(_STARTUPINFOEXW)), C_NULL, C_NULL, C_NULL,
        UInt32(0), UInt32(0), UInt32(0), UInt32(0),
        UInt32(0), UInt32(0), UInt32(0), _STARTF_USESTDHANDLES,
        UInt16(0), UInt16(0), C_NULL,
        inherited[1], inherited[2], inherited[3])
    attribute = _init_attribute_list(inherited, state)
    startup = Ref(_STARTUPINFOEXW(startup_base, attribute.list))
    process_info = Ref{_PROCESS_INFORMATION}()
    environment_pointer = envblock === nothing ? Ptr{UInt16}(C_NULL) : pointer(envblock)
    cwd_pointer = cwd === nothing ? Ptr{UInt16}(C_NULL) : pointer(cwd)
    creation_flags = _EXTENDED_STARTUPINFO_PRESENT
    envblock === nothing || (creation_flags |= _CREATE_UNICODE_ENVIRONMENT)

    state.stage = :create_process
    create_error = nothing
    attribute_buffer = attribute.buffer
    attribute_list = attribute.list
    created = try
        _check_phase_deadline(config, :create_process)
        _check_monitor_alive(state, :create_process)
        GC.@preserve parts envblock cwd inherited attribute_buffer startup process_info begin
            result = ccall(:CreateProcessW, stdcall, Int32,
                (Ptr{UInt16}, Ptr{UInt16}, Ptr{Cvoid}, Ptr{Cvoid}, Int32,
                 UInt32, Ptr{UInt16}, Ptr{UInt16}, Ptr{Cvoid}, Ref{_PROCESS_INFORMATION}),
                pointer(parts.application), pointer(parts.commandline),
                C_NULL, C_NULL, 1, creation_flags, environment_pointer,
                cwd_pointer, Base.unsafe_convert(Ptr{Cvoid}, startup),
                process_info)
            result == 0 && (create_error = Base.Libc.GetLastError())
            result
        end
    finally
        ccall(:DeleteProcThreadAttributeList, stdcall, Cvoid,
            (Ptr{Cvoid},), attribute_list)
    end
    created != 0 || _fail(:create_process,
        "CreateProcessW(inherited DEBUG_PROCESS gate) failed";
        win32_error=create_error)
    info = process_info[]
    state.process_handle = info.process
    state.thread_handle = info.thread
    state.pid = Int(info.process_id)
    state.thread_id = Int(info.thread_id)
    state.create_process_info_acquired = true
    state.process_acquisition_witness, process_witness_error =
        _duplicate_witness(state.process_handle)
    state.thread_acquisition_witness, thread_witness_error =
        _duplicate_witness(state.thread_handle)
    state.process_acquisition_witness != C_NULL ||
        _fail(:child_identity, "could not duplicate the original CreateProcessW process handle";
            win32_error=process_witness_error)
    state.thread_acquisition_witness != C_NULL ||
        _fail(:child_identity, "could not duplicate the original CreateProcessW thread handle";
            win32_error=thread_witness_error)
    _same_object(state.process_handle, state.process_acquisition_witness) ||
        _fail(:child_identity, "CreateProcessW process-handle witness is not the same object")
    _same_object(state.thread_handle, state.thread_acquisition_witness) ||
        _fail(:child_identity, "CreateProcessW thread-handle witness is not the same object")
    process_creation_time = _get_process_times(info.process, :child_identity)
    process_identity = _handle_identity(info.process, :child_process, :child_identity)
    process_identity.pid == state.pid &&
            process_identity.creation_time_100ns == process_creation_time ||
        _fail(:child_identity, "CreateProcessW process handle identity changed")
    state.creation_time_100ns = process_creation_time
    thread_identity = _thread_identity(info.thread, :child_identity)
    thread_identity.thread_id == Int(info.thread_id) && thread_identity.owner_pid == state.pid ||
        _fail(:child_identity, "CreateProcessW primary thread identity changed")
    state.thread_creation_time_100ns = thread_identity.creation_time_100ns

    for index in eachindex(state.inherited_handles)
        handle = state.inherited_handles[index]
        result = _release_owned_handle!(state, handle, :stdio,
            "CloseHandle(inherited stdio duplicate)";
            expected_identity=state.inherited_identities[index])
        (result.target_closed || result.ownership_transferred) &&
            (state.inherited_handles[index] = C_NULL)
        result.complete || _fail(:stdio_cleanup,
            "inherited stdio handle release is incomplete")
    end
    stdout_closed = _close_stdio_source!(state, :stdout_child, "close stdout child pipe";
        expected_identity=state.inherited_identities[2])
    stderr_closed = _close_stdio_source!(state, :stderr_child, "close stderr child pipe";
        expected_identity=state.inherited_identities[3])
    state.stdio_child_handles_closed = stdout_closed && stderr_closed
    state.stdio_child_handles_closed || _fail(:stdio_cleanup,
        "original child pipe handles did not close cleanly")
    (pid=state.pid, creation_time_100ns=state.creation_time_100ns)
end

function _read_ack_file(path::String, state::_State, config)
    stage = :ack_read
    wide = _widez(path, stage, "ACK path")
    handle = GC.@preserve wide ccall(:CreateFileW, stdcall, Ptr{Cvoid},
        (Ptr{UInt16}, UInt32, UInt32, Ptr{Cvoid}, UInt32, UInt32, Ptr{Cvoid}),
        pointer(wide), _GENERIC_READ, _FILE_SHARE_NONE, C_NULL, _OPEN_EXISTING,
        _FILE_FLAG_OPEN_REPARSE_POINT | _FILE_FLAG_SEQUENTIAL_SCAN, C_NULL)
    if handle == Ptr{Cvoid}(-1)
        code = Base.Libc.GetLastError()
        (code == _ERROR_FILE_NOT_FOUND || code == _ERROR_SHARING_VIOLATION) && return nothing
        _fail(stage, "CreateFileW(ACK) failed"; win32_error=code)
    end
    state.ack_handle = handle
    tag = Ref(_FILE_ATTRIBUTE_TAG_INFO(0, 0))
    ok = ccall(:GetFileInformationByHandleEx, stdcall, Int32,
        (Ptr{Cvoid}, UInt32, Ref{_FILE_ATTRIBUTE_TAG_INFO}, UInt32),
        handle, _FILE_ATTRIBUTE_TAG_INFO_CLASS, tag, UInt32(sizeof(_FILE_ATTRIBUTE_TAG_INFO)))
    _check_win32(ok, stage, "GetFileInformationByHandleEx(ACK) failed")
    (tag[].attributes & _FILE_ATTRIBUTE_REPARSE_POINT) == 0 ||
        _fail(stage, "ACK file is a reparse point")
    (tag[].attributes & _FILE_ATTRIBUTE_DIRECTORY) == 0 ||
        _fail(stage, "ACK path names a directory")
    identity = _file_identity(handle, stage)
    state.ack_file_identity = identity
    identity.size <= UInt64(_ACK_MAX_BYTES) ||
        _fail(stage, "ACK file exceeds the 64 KiB read limit")
    bytes = UInt8[]
    buffer = Vector{UInt8}(undef, 4096)
    while true
        requested = min(length(buffer), _ACK_MAX_BYTES + 1 - length(bytes))
        count = Ref{UInt32}(0)
        ok = GC.@preserve buffer ccall(:ReadFile, stdcall, Int32,
            (Ptr{Cvoid}, Ptr{UInt8}, UInt32, Ref{UInt32}, Ptr{Cvoid}),
            handle, pointer(buffer), UInt32(requested), count, C_NULL)
        if ok == 0
            code = Base.Libc.GetLastError()
            code == UInt32(38) && break
            _fail(stage, "ReadFile(ACK) failed"; win32_error=code)
        end
        count[] == 0 && break
        append!(bytes, @view buffer[1:Int(count[])])
        length(bytes) <= _ACK_MAX_BYTES ||
            _fail(stage, "ACK stream exceeds the 64 KiB read limit")
    end
    result = _release_owned_handle!(state, handle, :ack_file, "CloseHandle(ACK)";
        expected_identity=state.ack_file_identity)
    (result.target_closed || result.ownership_transferred) && (state.ack_handle = C_NULL)
    state.ack_handle_closed = result.target_closed
    result.complete || _fail(stage, "ACK handle close is unconfirmed")
    bytes
end

function _json_string(object::JSON3.Object, key::String)
    value = object[Symbol(key)]
    value isa String || _fail(:ack_validate, "ACK field " * key * " must be a string")
    value
end

function _json_integer(object::JSON3.Object, key::String, max_value::Int64)
    value = object[Symbol(key)]
    value isa Integer && !(value isa Bool) ||
        _fail(:ack_validate, "ACK field " * key * " must be a JSON integer, not bool")
    value > 0 && value <= max_value ||
        _fail(:ack_validate, "ACK field " * key * " is outside its positive range")
    Int64(value)
end

function _json_true(object::JSON3.Object, key::String)
    value = object[Symbol(key)]
    value isa Bool && value ||
        _fail(:ack_validate, "ACK field " * key * " must be literal true")
    true
end

function _skip_json_space(bytes::Vector{UInt8}, index::Int)
    while index <= length(bytes) && bytes[index] in (0x20, 0x09, 0x0a, 0x0d)
        index += 1
    end
    index
end

function _scan_json_string_end(bytes::Vector{UInt8}, index::Int)
    index <= length(bytes) && bytes[index] == UInt8('"') ||
        _fail(:ack_validate, "ACK JSON object key is not a string")
    index += 1
    while index <= length(bytes)
        byte = bytes[index]
        if byte == UInt8('\\')
            index += 2
        elseif byte == UInt8('"')
            return index
        else
            index += 1
        end
    end
    _fail(:ack_validate, "ACK JSON string is unterminated")
end

function _scan_json_value_end(bytes::Vector{UInt8}, index::Int)
    index = _skip_json_space(bytes, index)
    index <= length(bytes) || _fail(:ack_validate, "ACK JSON field has no value")
    depth = 0
    in_string = false
    escaped = false
    while index <= length(bytes)
        byte = bytes[index]
        if in_string
            if escaped
                escaped = false
            elseif byte == UInt8('\\')
                escaped = true
            elseif byte == UInt8('"')
                in_string = false
            end
        elseif byte == UInt8('"')
            in_string = true
        elseif byte == UInt8('{') || byte == UInt8('[')
            depth += 1
        elseif byte == UInt8('}') || byte == UInt8(']')
            if depth == 0
                byte == UInt8('}') || _fail(:ack_validate, "ACK JSON value has mismatched nesting")
                return index
            end
            depth -= 1
        elseif byte == UInt8(',') && depth == 0
            return index
        end
        index += 1
    end
    in_string && _fail(:ack_validate, "ACK JSON string is unterminated")
    depth == 0 || _fail(:ack_validate, "ACK JSON value has unterminated nesting")
    _fail(:ack_validate, "ACK JSON object is unterminated")
end

function _top_level_json_keys(bytes::Vector{UInt8})
    index = _skip_json_space(bytes, 1)
    index <= length(bytes) && bytes[index] == UInt8('{') ||
        _fail(:ack_validate, "ACK top-level JSON value is not an object")
    index += 1
    keys = String[]
    while true
        index = _skip_json_space(bytes, index)
        index <= length(bytes) || _fail(:ack_validate, "ACK JSON object is unterminated")
        if bytes[index] == UInt8('}')
            index += 1
            break
        end
        key_start = index
        key_end = _scan_json_string_end(bytes, index)
        token = String(copy(@view bytes[key_start:key_end]))
        key = try
            JSON3.read(token)
        catch err
            _fail(:ack_validate, "ACK JSON key is malformed: " * sprint(showerror, err))
        end
        key isa String || _fail(:ack_validate, "ACK JSON object key is not a string")
        push!(keys, key)
        index = _skip_json_space(bytes, key_end + 1)
        index <= length(bytes) && bytes[index] == UInt8(':') ||
            _fail(:ack_validate, "ACK JSON key lacks a colon")
        delimiter = _scan_json_value_end(bytes, index + 1)
        index = _skip_json_space(bytes, delimiter)
        if bytes[index] == UInt8(',')
            index += 1
        elseif bytes[index] == UInt8('}')
            index += 1
            break
        else
            _fail(:ack_validate, "ACK JSON object member delimiter is invalid")
        end
    end
    index = _skip_json_space(bytes, index)
    index == length(bytes) + 1 || _fail(:ack_validate, "ACK JSON has trailing content")
    keys
end

function _validate_ack(bytes::Vector{UInt8}, config, child_pid::Int,
        child_ticks::Int64, parent_pid::Int, parent_ticks::Int64)
    isempty(bytes) && _fail(:ack_validate, "ACK file is empty")
    last(bytes) == UInt8('\n') || _fail(:ack_validate, "ACK publication lacks final newline")
    parsed = try
        JSON3.read(String(copy(bytes)))
    catch err
        _fail(:ack_validate, "ACK is not valid UTF-8 JSON: " * sprint(showerror, err))
    end
    parsed isa JSON3.Object || _fail(:ack_validate, "ACK top-level value is not an object")
    names = _top_level_json_keys(bytes)
    length(names) == length(_ACK_KEYS) ||
        _fail(:ack_validate, "ACK has missing or extra fields")
    length(unique(names)) == length(names) ||
        _fail(:ack_validate, "ACK contains duplicate JSON object keys")
    Set(names) == _ACK_KEYS || _fail(:ack_validate, "ACK has a non-exact key set")

    schema = _json_string(parsed, "schema")
    schema == _ACK_SCHEMA || _fail(:ack_validate, "ACK schema is not supported")
    session = _json_string(parsed, "session_id")
    session == config.session_id || _fail(:ack_validate, "ACK session id does not match")
    scope = _json_string(parsed, "scope_sha256")
    scope == config.scope_sha256 || _fail(:ack_validate, "ACK scope SHA256 does not match")
    child_ack_pid = Int(_json_integer(parsed, "child_pid", Int64(typemax(UInt32))))
    child_ack_ticks = _json_integer(parsed, "child_creation_time_100ns", typemax(Int64))
    parent_ack_pid = Int(_json_integer(parsed, "parent_pid", Int64(typemax(UInt32))))
    parent_ack_ticks = _json_integer(parsed, "parent_creation_time_100ns", typemax(Int64))
    monitor_ack_pid = Int(_json_integer(parsed, "monitor_pid", Int64(typemax(UInt32))))
    monitor_ack_ticks = _json_integer(parsed, "monitor_creation_time_100ns", typemax(Int64))
    sequence = _json_integer(parsed, "registration_sequence", typemax(Int64))
    child_ack_pid == child_pid && child_ack_ticks == child_ticks ||
        _fail(:ack_validate, "ACK child identity does not match the retained CreateProcessW handles")
    parent_ack_pid == parent_pid && parent_ack_ticks == parent_ticks ||
        _fail(:ack_validate, "ACK parent identity does not match the current Julia process")
    monitor_ack_pid == config.monitor_pid && monitor_ack_ticks == config.monitor_ticks ||
        _fail(:ack_validate, "ACK monitor identity does not match the monitored environment")
    _json_true(parsed, "handle_duplicated")
    _json_true(parsed, "identity_registered")
    _json_true(parsed, "job_bound")
    _json_true(parsed, "creation_sample_measured")
    _json_true(parsed, "resume_permitted")
    complete = parsed[Symbol("full_run_resource_complete")]
    complete isa Bool && !complete ||
        _fail(:ack_validate, "startup ACK must not claim full-run resource completion")
    ManagedProcessAck(schema, session, scope, child_ack_pid, child_ack_ticks,
        parent_ack_pid, parent_ack_ticks, monitor_ack_pid, monitor_ack_ticks,
        sequence, true, true, true, true, true, false)
end

function _ack_names_for_pid(directory::String, pid::Int)
    names = String[]
    pattern = r"(?i)^([0-9]+)_([0-9]+)\.ack\.json$"
    for name in readdir(directory)
        found = match(pattern, name)
        found === nothing && continue
        parsed_pid = tryparse(Int, found.captures[1])
        parsed_pid == pid && push!(names, name)
    end
    names
end

function _await_ack(config, state::_State, child_pid::Int, child_ticks::Int64,
        parent_pid::Int, parent_ticks::Int64)
    state.stage = :ack_wait
    ack_name = string(child_pid, "_", child_ticks, ".ack.json")
    ack_path = joinpath(config.ack_directory, ack_name)
    now_tick = _tick64_ms()
    _check_phase_deadline(config, :ack_wait)
    handshake_ms = cld(config.handshake_ns, UInt64(1_000_000))
    ack_deadline = handshake_ms > typemax(UInt64) - now_tick ? typemax(UInt64) :
        min(config.deadline_tick64_ms, now_tick + handshake_ms)
    while true
        _check_phase_deadline(config, :ack_wait)
        _check_monitor_alive(state, :ack_wait)
        _tick64_ms() < ack_deadline || _fail(:ack_wait, "registration ACK deadline expired")
        bytes = _read_ack_file(ack_path, state, config)
        if bytes !== nothing
            ack_names = _ack_names_for_pid(config.ack_directory, child_pid)
            length(ack_names) == 1 && only(ack_names) == ack_name ||
                _fail(:ack_validate, "ACK directory contains duplicate or non-exact child identity files")
            _get_process_times(state.process_handle, :ack_validate) == child_ticks ||
                _fail(:ack_validate, "retained child handle identity changed")
            _get_process_times(state.monitor_handle, :ack_validate) == config.monitor_ticks ||
                _fail(:ack_validate, "retained monitor handle identity changed")
            _get_process_times(ccall(:GetCurrentProcess, stdcall, Ptr{Cvoid}, ()),
                :ack_validate) == parent_ticks ||
                _fail(:ack_validate, "current Julia parent identity changed")
            ack = _validate_ack(bytes, config, child_pid, child_ticks,
                parent_pid, parent_ticks)
            status = ccall(:WaitForSingleObject, stdcall, UInt32,
                (Ptr{Cvoid}, UInt32), state.process_handle, UInt32(0))
            (status == _WAIT_TIMEOUT || status == _WAIT_OBJECT_0) ||
                _fail(:ack_validate,
                    "cannot query child after registration ACK";
                    win32_error=status == _WAIT_FAILED ? Base.Libc.GetLastError() : nothing)
            _check_phase_deadline(config, :ack_validate)
            _check_monitor_alive(state, :ack_validate)
            return ack
        end
        status = ccall(:WaitForSingleObject, stdcall, UInt32,
            (Ptr{Cvoid}, UInt32), state.process_handle, UInt32(0))
        status == _WAIT_OBJECT_0 &&
            _fail(:ack_wait, "child process signaled before registration ACK")
        status == _WAIT_TIMEOUT ||
            _fail(:ack_wait, "cannot query child before registration ACK";
                win32_error=status == _WAIT_FAILED ? Base.Libc.GetLastError() : nothing)
        sleep(0.005)
    end
end

function _close_pipe_endpoint!(state::_State, field::Symbol, label::String)
    source = getfield(state, field)
    source === nothing && return true
    handle = try
        _handle_pointer(Base.rawhandle(source))
    catch
        C_NULL
    end
    identity = nothing
    witness = C_NULL
    duplicate_error = nothing
    if handle != C_NULL
        try
            identity = _handle_identity(handle, :capture_pipe, :cleanup_identity)
        catch err
            message = label * ": could not capture pipe identity: " * sprint(showerror, err)
            push!(state.cleanup_errors, message)
            _remember_pending!(state, :capture_pipe, handle, C_NULL, false, nothing,
                err isa _CaptureFailure ? err.win32_error : nothing, message; lease=source)
            setfield!(state, field, nothing)
            return false
        end
        witness, duplicate_error = _duplicate_witness(handle)
        if witness == C_NULL || !_handles_match(handle, witness, :capture_pipe,
                identity, :cleanup_identity) ||
                !_identity_matches(handle, :capture_pipe, identity, :cleanup_identity)
            message = label * ": could not retain/confirm pipe handle witness"
            push!(state.cleanup_errors, message)
            _remember_pending!(state, :capture_pipe, handle, witness, witness != C_NULL,
                identity, duplicate_error, message; lease=source)
            setfield!(state, field, nothing)
            return false
        end
    end
    try
        close(source)
        setfield!(state, field, nothing)
        handle == C_NULL && return true
        _close_witness!(state, witness, :capture_pipe, identity,
            label * " identity witness")
    catch err
        message = label * ": close failed: " * sprint(showerror, err)
        push!(state.cleanup_errors, message)
        _remember_pending!(state, :capture_pipe, handle, witness,
            witness != C_NULL, identity, nothing, message; lease=source)
        setfield!(state, field, nothing)
        false
    end
end

function _wait_for_child_during_cleanup!(state::_State)
    handle = state.process_handle
    handle == C_NULL && return state.process_signaled
    expected_identity = state.pid === nothing || state.creation_time_100ns === nothing ? nothing :
        (kind=:process, pid=state.pid, creation_time_100ns=state.creation_time_100ns)
    exact_createprocess_handle = state.create_process_info_acquired &&
        handle == state.process_handle
    exact_createprocess_handle || begin
        push!(state.cleanup_errors,
            "cleanup refuses to act on a process handle not retained from CreateProcessW")
        state.wait_signaled = false
        state.process_signaled = false
        return false
    end
    identity_matches = expected_identity !== nothing &&
        _identity_matches(handle, :child_process, expected_identity, :cleanup_identity)
    if !identity_matches
        push!(state.cleanup_errors,
            "process FILETIME identity is unavailable or inconsistent; cleanup uses only the original CreateProcessW hProcess")
    end
    if state.process_acquisition_witness != C_NULL &&
            !_same_object(handle, state.process_acquisition_witness)
        push!(state.cleanup_errors,
            "original CreateProcessW process handle differs from its retained CompareObjectHandles witness")
    end
    status = ccall(:WaitForSingleObject, stdcall, UInt32,
        (Ptr{Cvoid}, UInt32), handle, UInt32(0))
    if status == _WAIT_OBJECT_0
        state.process_signaled = true
        state.wait_signaled = true
        return true
    end
    if status == _WAIT_TIMEOUT || status == _WAIT_FAILED
        state.termination_attempted = true
        ok = ccall(:TerminateProcess, stdcall, Int32,
            (Ptr{Cvoid}, UInt32), handle, _CLEANUP_EXIT_CODE)
        if ok != 0
            state.termination_succeeded = true
        else
            state.termination_succeeded = false
            code = UInt32(Base.Libc.GetLastError())
            push!(state.cleanup_errors, "TerminateProcess: Win32 " * string(code))
        end
    else
        push!(state.cleanup_errors,
            "WaitForSingleObject before termination returned unexpected status " * string(status))
        return false
    end

    while true
        if !(state.create_process_info_acquired && handle == state.process_handle)
            push!(state.cleanup_errors,
                "original CreateProcessW hProcess ownership changed during bounded cleanup wait")
            state.wait_signaled = false
            state.process_signaled = false
            return false
        end
        waited = ccall(:WaitForSingleObject, stdcall, UInt32,
            (Ptr{Cvoid}, UInt32), handle, UInt32(0))
        if waited == _WAIT_OBJECT_0
            state.process_signaled = true
            state.wait_signaled = true
            return true
        elseif waited == _WAIT_TIMEOUT
            _retry_pause!(state) || break
        else
            push!(state.cleanup_errors,
                "WaitForSingleObject after termination failed: " * string(waited))
            break
        end
    end
    state.wait_signaled = false
    state.process_signaled = false
    false
end

function _pending_snapshot(state::_State)
    wanted = Set(state.pending_ids)
    records = lock(_PENDING_HANDLE_OWNER.lock) do
        [record for record in _PENDING_HANDLE_OWNER.records if record.id in wanted]
    end
    Tuple((id=record.id, kind=record.kind, identity=record.identity,
        last_error=record.last_error, reason=record.reason) for record in records)
end

function _remember_createprocess_pair!(state::_State, kind::Symbol,
        handle_field::Symbol, witness_field::Symbol, identity, reason::String)
    handle = getfield(state, handle_field)
    witness = getfield(state, witness_field)
    handle == C_NULL && witness == C_NULL && return (target_closed=true, complete=true)
    push!(state.cleanup_errors, reason)
    _remember_pending!(state, kind, handle, witness, witness != C_NULL,
        identity, nothing, reason)
    setfield!(state, handle_field, C_NULL)
    setfield!(state, witness_field, C_NULL)
    (target_closed=false, complete=false)
end

function _release_createprocess_pair!(state::_State, kind::Symbol,
        handle_field::Symbol, witness_field::Symbol, identity, label::String)
    handle = getfield(state, handle_field)
    witness = getfield(state, witness_field)
    if identity === nothing
        return _remember_createprocess_pair!(state, kind, handle_field, witness_field,
            nothing, label * ": acquisition FILETIME is unavailable; preserving original CreateProcessW handle pair")
    end
    if handle != C_NULL && witness != C_NULL &&
            !_handles_match(handle, witness, kind, identity, :cleanup_identity)
        return _remember_createprocess_pair!(state, kind, handle_field, witness_field,
            identity, label * ": retained CreateProcessW handle witness does not match")
    end

    target_closed = handle == C_NULL
    complete = true
    if handle != C_NULL
        result = _release_owned_handle!(state, handle, kind, label;
            expected_identity=identity)
        (result.target_closed || result.ownership_transferred) &&
            setfield!(state, handle_field, C_NULL)
        target_closed = result.target_closed
        complete &= result.complete
    end
    if witness != C_NULL
        result = _release_owned_handle!(state, witness, kind, label * " acquisition witness";
            expected_identity=identity)
        (result.target_closed || result.ownership_transferred) &&
            setfield!(state, witness_field, C_NULL)
        complete &= result.complete
    end
    (target_closed=target_closed, complete=complete)
end

function _cleanup!(state::_State)
    if state.process_handle != C_NULL
        if state.process_signaled || _wait_for_child_during_cleanup!(state)
            process_identity = state.creation_time_100ns === nothing || state.pid === nothing ? nothing :
                (kind=:process, pid=state.pid, creation_time_100ns=state.creation_time_100ns)
            result = _release_createprocess_pair!(state, :child_process,
                :process_handle, :process_acquisition_witness, process_identity,
                "CloseHandle(child process)")
            state.process_handle_closed = result.target_closed
        else
            expected_identity = state.pid === nothing || state.creation_time_100ns === nothing ? nothing :
                (kind=:process, pid=state.pid, creation_time_100ns=state.creation_time_100ns)
            _remember_createprocess_pair!(state, :child_process,
                :process_handle, :process_acquisition_witness, expected_identity,
                "unsignaled child remains owned by the original CreateProcessW handle pair")
            state.process_handle_closed = false
        end
    elseif state.process_handle_closed === nothing
        state.process_handle_closed = true
    end

    duplicate_closed = true
    for i in eachindex(state.inherited_handles)
        handle = state.inherited_handles[i]
        handle == C_NULL && continue
        result = _release_owned_handle!(state, handle, :stdio,
            "CloseHandle(inherited stdio)";
            expected_identity=state.inherited_identities[i])
        (result.target_closed || result.ownership_transferred) &&
            (state.inherited_handles[i] = C_NULL)
        duplicate_closed &= result.complete
    end

    stdout_source_identity = length(state.inherited_identities) >= 2 ?
        state.inherited_identities[2] : nothing
    stderr_source_identity = length(state.inherited_identities) >= 3 ?
        state.inherited_identities[3] : nothing
    child_closed = _close_stdio_source!(state, :stdout_child, "close stdout child pipe";
        expected_identity=stdout_source_identity)
    child_closed &= _close_stdio_source!(state, :stderr_child, "close stderr child pipe";
        expected_identity=stderr_source_identity)
    state.stdio_child_handles_closed = child_closed

    pipes_closed = _close_pipe_endpoint!(state, :stdout_reader, "close stdout capture pipe")
    pipes_closed &= _close_pipe_endpoint!(state, :stderr_reader, "close stderr capture pipe")

    tasks_done = all(task -> task === nothing || istaskdone(task),
        (state.stdout_task, state.stderr_task))
    while !tasks_done && _retry_pause!(state)
        tasks_done = all(task -> task === nothing || istaskdone(task),
            (state.stdout_task, state.stderr_task))
    end
    if tasks_done
        state.stdout_task = nothing
        state.stderr_task = nothing
    else
        message = "capture reader tasks remained pending at the original phase deadline"
        push!(state.cleanup_errors, message)
        _remember_pending!(state, :reader_task, C_NULL, C_NULL, false, nothing,
            nothing, message; lease=(stdout=state.stdout_reader, stderr=state.stderr_reader,
                stdout_task=state.stdout_task, stderr_task=state.stderr_task))
        state.stdout_task = nothing
        state.stderr_task = nothing
    end

    if state.thread_handle != C_NULL
        thread_identity = state.thread_id === nothing ||
                state.thread_creation_time_100ns === nothing || state.pid === nothing ? nothing :
            (kind=:thread, thread_id=state.thread_id, owner_pid=state.pid,
                creation_time_100ns=state.thread_creation_time_100ns)
        result = _release_createprocess_pair!(state, :child_thread,
            :thread_handle, :thread_acquisition_witness, thread_identity,
            "CloseHandle(child thread)")
        state.thread_handle_closed = result.target_closed
    elseif state.thread_handle_closed === nothing
        state.thread_handle_closed = true
    end
    if state.monitor_handle != C_NULL
        if state.monitor_identity === nothing
            message = "monitor handle lacks its acquisition identity"
            push!(state.cleanup_errors, message)
            _remember_pending!(state, :monitor_process, state.monitor_handle,
                C_NULL, false, nothing, nothing, message)
            state.monitor_handle = C_NULL
            state.monitor_handle_closed = false
        else
            result = _release_owned_handle!(state, state.monitor_handle,
                :monitor_process, "CloseHandle(monitor)";
                expected_identity=state.monitor_identity)
            (result.target_closed || result.ownership_transferred) &&
                (state.monitor_handle = C_NULL)
            state.monitor_handle_closed = result.target_closed
        end
    else
        state.monitor_handle_closed === nothing && (state.monitor_handle_closed = true)
    end
    if state.ack_handle != C_NULL
        if state.ack_file_identity === nothing
            message = "ACK file handle lacks its acquisition identity"
            push!(state.cleanup_errors, message)
            _remember_pending!(state, :ack_file, state.ack_handle,
                C_NULL, false, nothing, nothing, message)
            state.ack_handle = C_NULL
            state.ack_handle_closed = false
        else
            result = _release_owned_handle!(state, state.ack_handle,
                :ack_file, "CloseHandle(ACK file)";
                expected_identity=state.ack_file_identity)
            (result.target_closed || result.ownership_transferred) &&
                (state.ack_handle = C_NULL)
            state.ack_handle_closed = result.target_closed
        end
    elseif state.ack_handle_closed === nothing
        state.ack_handle_closed = true
    end

    state.thread_handle_closed === nothing && state.pid === nothing &&
        (state.thread_handle_closed = true)
    state.process_handle_closed === nothing && state.pid === nothing &&
        (state.process_handle_closed = true)
    state.pipes_closed = pipes_closed
    state.reader_tasks_done = tasks_done
    pending = _pending_snapshot(state)
    duplicate_closed &= !any(record -> record.kind == :stdio, pending)
    child_closed &= !any(record -> record.kind == :stdio_source, pending)
    state.stdio_child_handles_closed = child_closed
    cleanup_complete =
        (state.pid === nothing || (state.process_signaled && state.wait_signaled === true)) &&
        state.process_handle_closed === true && state.thread_handle_closed === true &&
        state.monitor_handle_closed === true && state.ack_handle_closed === true &&
        duplicate_closed && child_closed &&
        pipes_closed && tasks_done && isempty(pending) && isempty(state.cleanup_errors)
    (process_created=state.pid !== nothing,
     termination_attempted=state.termination_attempted,
     termination_succeeded=state.termination_succeeded,
     wait_signaled=state.wait_signaled,
     process_handle_closed=state.process_handle_closed,
     thread_handle_closed=state.thread_handle_closed,
     monitor_handle_closed=state.monitor_handle_closed,
     ack_handle_closed=state.ack_handle_closed,
     inherited_stdio_handles_closed=duplicate_closed,
     original_stdio_handles_closed=child_closed,
     capture_pipes_closed=pipes_closed,
     reader_tasks_done=tasks_done,
     pending_handles=pending,
     pending_handle_ids=Tuple(state.pending_ids),
     handle_close_failures=Tuple(state.handle_close_failures),
     cleanup_complete=cleanup_complete,
     errors=Tuple(state.cleanup_errors))
end

function _capture_windows(command::Cmd; as_bytes::Bool=false)
    state = _State()
    try
        Sys.WORD_SIZE == 64 || _fail(:platform, "managed client requires 64-bit Julia")
        config = _managed_environment()
        state.deadline_tick64_ms = config.deadline_tick64_ms
        _monitor_handle(config, state)
        state.stage = :parent_identity
        parent_handle = ccall(:GetCurrentProcess, stdcall, Ptr{Cvoid}, ())
        parent_pid_u32 = ccall(:GetCurrentProcessId, stdcall, UInt32, ())
        parent_ticks = _get_process_times(parent_handle, :parent_identity)
        parent_pid = Int(parent_pid_u32)

        child_identity = _create_debug_event_gated(command, config, state)
        state.stage = :ack_validate
        ack = _await_ack(config, state, child_identity.pid,
            child_identity.creation_time_100ns, parent_pid, parent_ticks)
        _check_phase_deadline(config, :capture_start)
        _check_monitor_alive(state, :capture_start)

        state.stage = :capture_start
        state.stdout_task = @async read(state.stdout_reader)
        state.stderr_task = @async read(state.stderr_reader)
        yield()

        # The inherited monitor owns the initial CREATE debug-event release.
        # This client validates its exact ACK but never calls ResumeThread.

        state.stage = :process_wait
        while true
            _check_phase_deadline(config, :process_wait)
            _check_monitor_alive(state, :process_wait)
            status = ccall(:WaitForSingleObject, stdcall, UInt32,
                (Ptr{Cvoid}, UInt32), state.process_handle, UInt32(0))
            if status == _WAIT_OBJECT_0
                _check_phase_deadline(config, :process_wait)
                state.process_signaled = true
                state.wait_signaled = true
                break
            elseif status != _WAIT_TIMEOUT
                _fail(:process_wait, "WaitForSingleObject(child) failed";
                    win32_error=status == _WAIT_FAILED ? Base.Libc.GetLastError() : nothing)
            end
            yield()
            sleep(0.005)
        end

        state.stage = :exit_code
        exit_code = Ref{UInt32}(0)
        ok = ccall(:GetExitCodeProcess, stdcall, Int32,
            (Ptr{Cvoid}, Ref{UInt32}), state.process_handle, exit_code)
        _check_win32(ok, :exit_code, "GetExitCodeProcess failed")
        state.stage = :capture_read
        while !istaskdone(state.stdout_task) || !istaskdone(state.stderr_task)
            _check_phase_deadline(config, :capture_read)
            _check_monitor_alive(state, :capture_read)
            yield()
            sleep(0.005)
        end
        stdout_bytes = fetch(state.stdout_task)::Vector{UInt8}
        stderr_bytes = fetch(state.stderr_task)::Vector{UInt8}
        _check_phase_deadline(config, :capture_read)
        _check_monitor_alive(state, :capture_read)
        state.stage = :cleanup
        cleanup = _cleanup!(state)
        isempty(cleanup.errors) ||
            _fail(:cleanup, "one or more process/stdio handles failed to close")
        cleanup.process_handle_closed && cleanup.thread_handle_closed &&
            cleanup.monitor_handle_closed && cleanup.inherited_stdio_handles_closed &&
            cleanup.original_stdio_handles_closed && cleanup.capture_pipes_closed &&
            cleanup.reader_tasks_done && cleanup.cleanup_complete ||
            _fail(:cleanup, "process cleanup evidence is incomplete")
        stdout_value = as_bytes ? stdout_bytes : String(stdout_bytes)
        (stdout=stdout_value, stderr=stderr_bytes, exit_code=Int(exit_code[]),
         pid=child_identity.pid,
         creation_time_100ns=child_identity.creation_time_100ns,
         registration_ack=ack,
         startup_hold_kind="inherited_debug_create_event",
         startup_release_authority="monitor_continue_debug_event")
    catch err
        cleanup = _cleanup!(state)
        failure = err isa _CaptureFailure ? err :
            _CaptureFailure(state.stage, nothing, sprint(showerror, err))
        throw(ManagedProcessError(failure.stage, failure.win32_error, state.pid,
            state.creation_time_100ns, failure.message, cleanup))
    end
end

function capture(command::Cmd; as_bytes::Bool=false)
    Sys.iswindows() ||
        throw(ManagedProcessError(:platform, nothing, nothing, nothing,
            "managed debug-event gated capture requires Windows",
            (process_created=false,)))
    _capture_windows(command; as_bytes=as_bytes)
end

end # module
