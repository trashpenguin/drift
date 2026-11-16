//! Small platform shims so the rest of the app stays free of `cfg` noise.

use std::path::PathBuf;
use std::process::Command;

pub fn program_path(name: &str) -> Option<PathBuf> {
    #[cfg(windows)]
    let filename = format!("{name}.exe");
    #[cfg(not(windows))]
    let filename = name;

    let path = std::env::var_os("PATH").unwrap_or_default();
    let dirs = std::env::split_paths(&path);
    #[cfg(windows)]
    let dirs = {
        let app_dir = std::env::current_exe()
            .ok()
            .and_then(|exe| exe.parent().map(PathBuf::from));
        let windows = std::env::var_os("SystemRoot").map(PathBuf::from);
        app_dir
            .into_iter()
            .chain(windows.as_ref().map(|root| root.join("System32")))
            .chain(windows)
            .chain(dirs)
    };
    dirs.map(|dir| dir.join(&filename))
        .find(|path| {
            let Ok(metadata) = path.metadata() else {
                return false;
            };
            #[cfg(unix)]
            {
                use std::os::unix::fs::PermissionsExt;
                if metadata.permissions().mode() & 0o111 == 0 {
                    return false;
                }
            }
            metadata.is_file()
        })
        .and_then(|path| std::path::absolute(path).ok())
}

pub fn command(name: &str) -> Command {
    Command::new(program_path(name).unwrap_or_else(|| PathBuf::from(name)))
}

/// Keep child processes from flashing a console window on Windows.
pub fn no_window(cmd: &mut Command) -> &mut Command {
    #[cfg(windows)]
    {
        use std::os::windows::process::CommandExt;
        const CREATE_NO_WINDOW: u32 = 0x0800_0000;
        cmd.creation_flags(CREATE_NO_WINDOW);
    }
    cmd
}

/// Windows: make sure `child` is killed when drift exits, even if drift
/// crashes (the equivalent of Linux's PR_SET_PDEATHSIG).
#[cfg(windows)]
pub fn kill_on_exit(child: &std::process::Child) {
    use std::ffi::c_void;
    use std::os::windows::io::AsRawHandle;
    use std::sync::OnceLock;

    #[repr(C)]
    struct BasicLimits {
        per_process_user_time_limit: i64,
        per_job_user_time_limit: i64,
        limit_flags: u32,
        minimum_working_set_size: usize,
        maximum_working_set_size: usize,
        active_process_limit: u32,
        affinity: usize,
        priority_class: u32,
        scheduling_class: u32,
    }
    #[repr(C)]
    struct IoCounters([u64; 6]);
    #[repr(C)]
    struct ExtendedLimits {
        basic: BasicLimits,
        io: IoCounters,
        process_memory_limit: usize,
        job_memory_limit: usize,
        peak_process_memory_used: usize,
        peak_job_memory_used: usize,
    }

    extern "system" {
        fn CreateJobObjectW(attrs: *mut c_void, name: *const u16) -> *mut c_void;
        fn SetInformationJobObject(
            job: *mut c_void,
            class: i32,
            info: *mut c_void,
            len: u32,
        ) -> i32;
        fn AssignProcessToJobObject(job: *mut c_void, process: *mut c_void) -> i32;
    }

    const JOB_OBJECT_EXTENDED_LIMIT_INFORMATION: i32 = 9;
    const KILL_ON_JOB_CLOSE: u32 = 0x2000;

    // The job handle is intentionally kept open for the life of the process;
    // when drift exits (or dies) Windows closes it and kills everything in it.
    static JOB: OnceLock<usize> = OnceLock::new();
    let job = *JOB.get_or_init(|| unsafe {
        let job = CreateJobObjectW(std::ptr::null_mut(), std::ptr::null());
        if job.is_null() {
            return 0;
        }
        let mut info: ExtendedLimits = std::mem::zeroed();
        info.basic.limit_flags = KILL_ON_JOB_CLOSE;
        let ok = SetInformationJobObject(
            job,
            JOB_OBJECT_EXTENDED_LIMIT_INFORMATION,
            &mut info as *mut _ as *mut c_void,
            std::mem::size_of::<ExtendedLimits>() as u32,
        );
        if ok == 0 {
            return 0;
        }
        job as usize
    });
    if job != 0 {
        unsafe {
            AssignProcessToJobObject(job as *mut c_void, child.as_raw_handle() as *mut c_void);
        }
    }
}

#[cfg(not(windows))]
pub fn kill_on_exit(_child: &std::process::Child) {}
