@{
    # Visual Studio / MSVC
    MSVC  = @{
        Root       = 'D:\Program Files (x86)\Microsoft Visual Studio\18\BuildTools'
        InstanceId = 'bc7fba05'
        Version    = '14.50'
        TargetArch = 'x64'
        HostArch   = 'x64'
        Language   = '1033'
    }

    # CUDA Toolkit
    CUDA  = @{
        Root          = 'D:\Program Files\NVIDIA GPU Computing Tools\CUDA\v13.2'
        Version       = '13.2'
        TorchCudaArch = '8.9'
    }

    # cuDNN
    CUDNN = @{
        Root          = 'D:\Program Files\NVIDIA\CUDNN\v9.22'
        Version       = '9.22'
        RuntimeSubDir = 'bin\13.2\x64'
    }
}