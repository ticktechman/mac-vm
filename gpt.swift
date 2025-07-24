import Foundation

// GPT partition type GUID mapping table
let partition_type_guids: [String: String] = [
  "00000000-0000-0000-0000-000000000000": "Unused Partition",

  // EFI System Partition
  "C12A7328-F81F-11D2-BA4B-00A0C93EC93B": "EFI System Partition",

  // Microsoft
  "E3C9E316-0B5C-4DB8-817D-F92DF00215AE": "Microsoft Reserved Partition (MSR)",
  "EBD0A0A2-B9E5-4433-87C0-68B6B72699C7": "Microsoft Basic Data Partition",
  "DE94BBA4-06D1-4D40-A16A-BFD50179D6AC": "Windows Recovery Environment (Windows RE)",
  "37AFFC90-EF7D-4E96-91C3-2D7AE055B174": "Microsoft Storage Spaces",
  "5808C8AA-7E8F-42E0-85D2-E1E90434CFB3": "Microsoft Logical Disk Manager Metadata Partition",
  "AF9B60A0-1431-4F62-BC68-3311714A69AD": "Microsoft Logical Disk Manager Data Partition",

  // Linux
  "0FC63DAF-8483-4772-8E79-3D69D8477DE4": "Linux Filesystem Data",
  "0657FD6D-A4AB-43C4-84E5-0933C84B4F4F": "Linux Swap",
  "E6D6D379-F507-44C2-A23C-238F2A3DF928": "Linux LVM",
  "933AC7E1-2EB4-4F13-B844-0E14E2AEF915": "Linux /home",
  "44479540-F297-41B2-9AF7-D131D5F0458A": "Linux RAID",
  "A19D880F-05FC-4D3B-A006-743F0F84911E": "Linux /home",
  "BC13C2FF-59E6-4262-A352-B275FD6F7172": "Linux Extended Partition",
  "D3BFE2DE-3DAF-11DF-BA40-E3A556D89593": "BIOS Boot Partition",

  // BSD
  "516E7CB4-6ECF-11D6-8FF8-00022D09712B": "FreeBSD Data",
  "516E7CB5-6ECF-11D6-8FF8-00022D09712B": "FreeBSD Swap",
  "516E7CB6-6ECF-11D6-8FF8-00022D09712B": "FreeBSD UFS",
  "516E7CB8-6ECF-11D6-8FF8-00022D09712B": "FreeBSD Vinum Volume Manager",

  // Solaris
  "6A82CB45-1DD2-11B2-99A6-080020736631": "Solaris Boot",
  "6A85CF4D-1DD2-11B2-99A6-080020736631": "Solaris Root",
  "6A87C46F-1DD2-11B2-99A6-080020736631": "Solaris Swap",
  "6A8B642B-1DD2-11B2-99A6-080020736631": "Solaris Backup",
  "6A8EF2E9-1DD2-11B2-99A6-080020736631": "Solaris /usr",
  "6A90BA39-1DD2-11B2-99A6-080020736631": "Solaris /var",
  "6A9283A5-1DD2-11B2-99A6-080020736631": "Solaris /home",

  // Other
  "024DEE41-33E7-11D3-9D69-0008C781F39F": "MBR Protective",
  "49F48D5A-B10E-11DC-B99B-0019D1879648": "NetBSD Swap",
  "49F48D32-B10E-11DC-B99B-0019D1879648": "NetBSD FFS",
  "49F48D82-B10E-11DC-B99B-0019D1879648": "NetBSD LFS",
  "8A7CA206-26F4-11DB-8B10-0800200C9A66": "QNX 6.x",
  "E75CAF8F-F680-4CEE-ADF1-F3D969532F8C": "Windows Storage Spaces",
  "21686148-6449-6E6F-744E-656564454649": "BIOS Boot Partition",
  "426F6F74-0000-11AA-AA11-00306543ECAC": "Apple Boot Partition",
]

// Read bytes from file at specified offset and length
func read_bytes(from file_handle: FileHandle, offset: UInt64, length: Int) throws -> Data {
  try file_handle.seek(toOffset: offset)
  return try file_handle.read(upToCount: length) ?? Data()
}

func guid_bytes_to_uuid_string(_ bytes: Data) -> String? {
  guard bytes.count == 16 else { return nil }
  // Adjust GPT GUID byte order
  let data1 = Data(bytes[0...3].reversed())
  let data2 = Data(bytes[4...5].reversed())
  let data3 = Data(bytes[6...7].reversed())
  let data4 = bytes[8...15]

  let all_bytes = data1 + data2 + data3 + data4

  let hex_strings = all_bytes.map { String(format: "%02X", $0) }
  guard hex_strings.count == 16 else { return nil }
  return "\(hex_strings[0])\(hex_strings[1])\(hex_strings[2])\(hex_strings[3])-"
    + "\(hex_strings[4])\(hex_strings[5])-" + "\(hex_strings[6])\(hex_strings[7])-"
    + "\(hex_strings[8])\(hex_strings[9])-"
    + "\(hex_strings[10])\(hex_strings[11])\(hex_strings[12])\(hex_strings[13])\(hex_strings[14])\(hex_strings[15])"
}

// Parse GPT partition table and print info for specified partition numbers
func parse_gpt(
  from raw_file_path: String,
  sector_size: Int = 512,
  filter_partition_numbers: Set<Int>
) throws {
  let file_handle = try FileHandle(forReadingFrom: URL(fileURLWithPath: raw_file_path))

  // Read GPT header (LBA1)
  let gpt_header_offset = UInt64(sector_size)
  let gpt_header_data = try read_bytes(
    from: file_handle,
    offset: gpt_header_offset,
    length: sector_size
  )

  let signature = String(bytes: gpt_header_data.prefix(8), encoding: .ascii)
  guard signature == "EFI PART" else {
    throw NSError(
      domain: "GPT",
      code: 1,
      userInfo: [NSLocalizedDescriptionKey: "Not a valid GPT disk"]
    )
  }

  let partition_entry_lba = gpt_header_data.subdata(in: 72..<80).withUnsafeBytes {
    $0.load(as: UInt64.self).littleEndian
  }
  let number_of_entries = gpt_header_data.subdata(in: 80..<84).withUnsafeBytes {
    $0.load(as: UInt32.self).littleEndian
  }
  let entry_size = gpt_header_data.subdata(in: 84..<88).withUnsafeBytes {
    $0.load(as: UInt32.self).littleEndian
  }

  let partition_table_offset = UInt64(partition_entry_lba) * UInt64(sector_size)
  let total_partition_bytes = Int(number_of_entries) * Int(entry_size)
  let partition_table_data = try read_bytes(
    from: file_handle,
    offset: partition_table_offset,
    length: total_partition_bytes
  )

  for i in 0..<number_of_entries {
    let partition_number = Int(i) + 1  // GPT partition numbers start at 1
    guard filter_partition_numbers.contains(partition_number) else {
      continue
    }

    let entry_offset = Int(i) * Int(entry_size)
    let entry_data = partition_table_data.subdata(in: entry_offset..<entry_offset + Int(entry_size))

    // Partition type GUID
    let type_guid_data = entry_data.subdata(in: 0..<16)
    guard let type_guid_string = guid_bytes_to_uuid_string(type_guid_data) else {
      print("Partition \(partition_number) type GUID parse failed")
      continue
    }

    // Skip unused partitions (all zero GUID)
    if type_guid_data.allSatisfy({ $0 == 0 }) {
      continue
    }

    // Start and end LBA
    let start_lba = entry_data.subdata(in: 32..<40).withUnsafeBytes {
      $0.load(as: UInt64.self).littleEndian
    }
    let end_lba = entry_data.subdata(in: 40..<48).withUnsafeBytes {
      $0.load(as: UInt64.self).littleEndian
    }
    let size_in_mb = (end_lba - start_lba + 1) * UInt64(sector_size) / 1024 / 1024

    // Partition name UTF-16LE
    let name_data = entry_data.subdata(in: 56..<128)
    let name =
      String(data: name_data, encoding: .utf16LittleEndian)?
      .trimmingCharacters(in: .controlCharacters) ?? "(Unnamed)"

    let type_name = partition_type_guids[type_guid_string] ?? "Unknown"

    print("Partition \(partition_number)")
    print("  Type GUID : \(type_guid_string)")
    print("  Type Name : \(type_name)")
    print("  Start LBA : \(start_lba)")
    print("  End LBA   : \(end_lba)")
    print("  Size      : \(size_in_mb) MB")
    print("  Name      : \(name)\n")
  }

  file_handle.closeFile()
}

// Command line entry
if CommandLine.argc < 2 {
  print("Usage: swift ParseGPTFilter.swift /path/to/diskimage.raw")
  exit(1)
}

let raw_file = CommandLine.arguments[1]
let filter_partitions: Set<Int> = [1, 13, 15]

do {
  try parse_gpt(from: raw_file, filter_partition_numbers: filter_partitions)
}
catch {
  print("Error: \(error.localizedDescription)")
}
