import Foundation
import Virtualization

// Paths to kernel, initrd, and rootfs
let kernelURL = URL(fileURLWithPath: "./images/vmlinuz")
let initialRamdiskURL = URL(fileURLWithPath: "./images/initrd")
let rootfs = URL(fileURLWithPath: "./images/rootfs.raw")

// Create the Virtual Machine Configuration
let configuration = VZVirtualMachineConfiguration()
configuration.cpuCount = 2
configuration.memorySize = 2 * 1024 * 1024 * 1024  // 2 GiB
configuration.serialPorts = [createConsoleConfiguration()]
configuration.bootLoader = createBootLoader(
  kernelURL: kernelURL,
  initialRamdiskURL: initialRamdiskURL
)

// rootfs and seed(for cloud-init)
let seedISOURL = URL(fileURLWithPath: "./seed.iso")
do {
  let disk_attachment = try VZDiskImageStorageDeviceAttachment(url: rootfs, readOnly: false)
  let disk_device = VZVirtioBlockDeviceConfiguration(attachment: disk_attachment)
  configuration.storageDevices.append(disk_device)

  let seedAttachment = try VZDiskImageStorageDeviceAttachment(url: seedISOURL, readOnly: true)
  let seedCDROM = VZVirtioBlockDeviceConfiguration(attachment: seedAttachment)
  configuration.storageDevices.append(seedCDROM)

  // configure network
  let networkDevice = VZVirtioNetworkDeviceConfiguration()
  networkDevice.attachment = VZNATNetworkDeviceAttachment()
  configuration.networkDevices = [networkDevice]

  try configuration.validate()
}
catch {
  print("configuration failed: \(error)")
  exit(EXIT_FAILURE)
}

// Instantiate and Start the Virtual Machine
let virtualMachine = VZVirtualMachine(configuration: configuration)
let delegate = Delegate()
virtualMachine.delegate = delegate

virtualMachine.start { (result) in
  if case let .failure(error) = result {
    print("Failed to start the virtual machine. \(error)")
    exit(EXIT_FAILURE)
  }
}

RunLoop.main.run(until: Date.distantFuture)

// Virtual Machine Delegate
class Delegate: NSObject {}
extension Delegate: VZVirtualMachineDelegate {
  func guestDidStop(_ virtualMachine: VZVirtualMachine) {
    print("The guest shut down. Exiting.")
    exit(EXIT_SUCCESS)
  }
}

// Creates a Linux bootloader with the given kernel and initial ramdisk.
func createBootLoader(kernelURL: URL, initialRamdiskURL: URL) -> VZBootLoader {
  let bootLoader = VZLinuxBootLoader(kernelURL: kernelURL)
  bootLoader.initialRamdiskURL = initialRamdiskURL

  let kernelCommandLineArguments = [
    "console=hvc0",
    "root=/dev/vda1",
    "rw",
  ]
  bootLoader.commandLine = kernelCommandLineArguments.joined(separator: " ")

  return bootLoader
}

// serial port console for IO
func createConsoleConfiguration() -> VZSerialPortConfiguration {
  let consoleConfiguration = VZVirtioConsoleDeviceSerialPortConfiguration()

  let inputFileHandle = FileHandle.standardInput
  let outputFileHandle = FileHandle.standardOutput

  var attributes = termios()
  tcgetattr(inputFileHandle.fileDescriptor, &attributes)
  attributes.c_iflag &= ~tcflag_t(ICRNL)
  attributes.c_lflag &= ~tcflag_t(ICANON | ECHO)
  tcsetattr(inputFileHandle.fileDescriptor, TCSANOW, &attributes)

  let stdioAttachment = VZFileHandleSerialPortAttachment(
    fileHandleForReading: inputFileHandle,
    fileHandleForWriting: outputFileHandle
  )

  consoleConfiguration.attachment = stdioAttachment
  return consoleConfiguration
}
