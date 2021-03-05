//
//  Compressor.swift
//  Compressor
//
//  Created by Andrei Marincas on 1/31/18.
//  Copyright © 2018 Andrei Marincas. All rights reserved.
//

import Foundation
import Compression

enum OptionType: String {
    case encode     = "-encode"
    case decode     = "-decode"
    case concat     = "-concat"
    case split      = "-split"
    case input      = "-i"
    case output     = "-o"
    case bytesCount = "-no_bytes"
    case concatMap  = "-map"
}

enum State {
    case `init`
    case ready
    case waiting
}

class Compressor {
    
    private let fileManager = FileManager.default
    private var state: State = .init
    
    private var operation: OptionType!
    private var inputPath: String!
    private var outputPath: String!
    private var expectedBytesCountAfterDecode: Int?
    private var concatMapPath: String?
    
    init?() {
        if !validateOptions() {
            Console.printUsage()
            return nil
        }
        guard validateInputPath() else { return nil }
        validateOutputPath()
        guard validateVars() else { return nil }
    }
    
    private func validateOptions() -> Bool {
        guard CommandLine.argc >= 6 else { return false }
        if let op = OptionType(rawValue: CommandLine.arguments[1]),
            op == .encode || op == .decode || op == .concat || op == .split {
            operation = op
        } else {
            return false
        }
        guard OptionType(rawValue: CommandLine.arguments[2]) == .input else { return false }
        guard OptionType(rawValue: CommandLine.arguments[4]) == .output else { return false }
        if operation == .decode {
            guard CommandLine.argc >= 8, OptionType(rawValue: CommandLine.arguments[6]) == .bytesCount else { return false }
        } else if operation == .split {
            guard CommandLine.argc >= 8, OptionType(rawValue: CommandLine.arguments[6]) == .concatMap else { return false }
        }
        return true
    }
    
    private func validateInputPath() -> Bool {
        inputPath = CommandLine.arguments[3]
        if operation == .encode || operation == .decode {
            if !fileManager.fileExists(atPath: inputPath) {
                Console.print("Input file missing: " + inputPath, to: .error)
                return false
            }
        } else if operation == .concat {
            var isDir: ObjCBool = false
            if !fileManager.fileExists(atPath: inputPath, isDirectory: &isDir) {
                Console.print("Input directory missing: " + inputPath, to: .error)
                return false
            }
            if !isDir.boolValue {
                Console.print("Input is not a directory: " + inputPath, to: .error)
                return false
            }
        }
        return true
    }
    
    private func validateOutputPath() {
        outputPath = CommandLine.arguments[5]
        if operation == .encode || operation == .decode || operation == .concat {
            var isDir: ObjCBool = false
            if fileManager.fileExists(atPath: outputPath, isDirectory: &isDir) && !isDir.boolValue {
                Console.print("Output file already exists: " + outputPath)
                Console.print("Overwrite [y|n]? (Press `y` to delete the existing file and continue)")
                state = .waiting
            } else {
                state = .ready
            }
        } else if operation == .split {
            var isDir: ObjCBool = false
            if fileManager.fileExists(atPath: outputPath, isDirectory: &isDir) && isDir.boolValue {
                Console.print("Output directory already exists: " + outputPath)
                Console.print("Overwrite [y|n]? (Press `y` to delete the existing directory and continue)")
                state = .waiting
            } else {
                state = .ready
            }
        }
    }
    
    private func validateVars() -> Bool {
        if operation == .decode {
            let bytesCountArg = CommandLine.arguments[7]
            if let bytesCount = Int(bytesCountArg), bytesCount > 0 {
                expectedBytesCountAfterDecode = bytesCount
            } else {
                Console.print("Invalid argument for \(OptionType.bytesCount.rawValue): \(bytesCountArg)", to: .error)
                return false
            }
        } else if operation == .split {
            let mapPath = CommandLine.arguments[7]
            if fileManager.fileExists(atPath: mapPath) {
                concatMapPath = mapPath
            } else {
                Console.print("Concat map file not found: " + mapPath, to: .error)
                return false
            }
        }
        return true
    }
    
    private func encode() throws {
        var inputData = try Data(contentsOf: URL(fileURLWithPath: inputPath))
        let bytesCount = inputData.count
        let dstBuffer = malloc(bytesCount * MemoryLayout<UInt8>.stride)
        guard let dstBufferPtr = dstBuffer?.bindMemory(to: UInt8.self, capacity: bytesCount) else {
            Console.print("Couldn't allocate destination buffer for encode.", to: .error)
            return
        }
        Console.print("Ready to encode.")
        try inputData.withUnsafeBytes { (inputDataPtr: UnsafePointer<UInt8>) -> Void in
            Console.print("Compressing...")
            let compressedSize = compression_encode_buffer(dstBufferPtr, bytesCount, inputDataPtr, bytesCount, nil, COMPRESSION_LZFSE)
            Console.print("Original size: \(bytesCount)")
            Console.print("Compressed size: \(compressedSize)")
            let compressedData = Data(bytesNoCopy: dstBuffer!, count: compressedSize, deallocator: .none)
            try compressedData.write(to: URL(fileURLWithPath: outputPath))
            free(dstBuffer)
            Console.print("Encode completed successfully!")
        }
    }
    
    private func decode() throws {
        let inputData = try Data(contentsOf: URL(fileURLWithPath: inputPath))
        let originalBytesCount = expectedBytesCountAfterDecode!
        let dstBuffer = malloc(originalBytesCount * MemoryLayout<UInt8>.stride)
        guard let dstBufferPtr = dstBuffer?.bindMemory(to: UInt8.self, capacity: originalBytesCount) else {
            Console.print("Couldn't allocate destination buffer for decode.", to: .error)
            return
        }
        Console.print("Ready to decode.")
        try inputData.withUnsafeBytes { (inputDataPtr: UnsafePointer<UInt8>) -> Void in
            Console.print("Decoding...")
            let decompressedSize = compression_decode_buffer(dstBufferPtr, originalBytesCount, inputDataPtr, inputData.count, nil, COMPRESSION_LZFSE)
            if decompressedSize == originalBytesCount {
                let decompressedData = Data(bytesNoCopy: dstBuffer!, count: decompressedSize, deallocator: .none)
                try decompressedData.write(to: URL(fileURLWithPath: outputPath))
                free(dstBuffer)
                Console.print("Decode completed successfully!")
            } else {
                Console.print("Failed to decode! decompressed_size: \(decompressedSize), expected: \(originalBytesCount) bytes", to: .error)
            }
        }
    }
    
    private func concat() throws {
        let contents = try fileManager.contentsOfDirectory(atPath: inputPath)
        if contents.isEmpty {
            Console.print("No files to concat.", to: .error)
            return
        }
        Console.print("Trying to concat \(contents.count) images from the input directory.")
        var data = Data()
        var concatCount = 0
        var concatMap = ""
        for i in 0..<contents.count {
            let fileName = contents[i]
            let ext = (fileName as NSString).pathExtension.lowercased()
            let filePath = (inputPath as NSString).appendingPathComponent(fileName)
            if ext == "jpg" || ext == "jpeg" {
                if let imgData = fileManager.contents(atPath: filePath) {
                    Console.print("Concat \(imgData.count) bytes from \(fileName)")
                    data.append(imgData)
                    concatMap += "\(imgData.count)"
                    if i < contents.count - 1 {
                        concatMap.append("\n")
                    }
                    concatCount += 1
                } else {
                    Console.print("Failed to load data for image: " + filePath, to: .error)
                }
            } else {
                Console.print("Not a JPG image: " + filePath, to: .error)
            }
        }
        Console.print("Skipped: \(contents.count - concatCount) files")
        Console.print("Appended: \(concatCount) / \(contents.count) files")
        Console.print("Concat total: \(data.count) bytes")
        try data.write(to: URL(fileURLWithPath: outputPath))
        
        // Write concat map
        Console.print("Writing map file...")
        let concatMapURL = URL(fileURLWithPath: outputPath + "-map.data")
        if fileManager.fileExists(atPath: concatMapURL.path) {
            try? fileManager.removeItem(at: concatMapURL)
        }
        try? concatMap.data(using: .utf8)?.write(to: concatMapURL)
        
        Console.print("Concat completed successfully!")
    }
    
    private func split() throws {
        let inputURL = URL(fileURLWithPath: inputPath)
        var inputData = try Data(contentsOf: inputURL)
        let inputName = inputURL.deletingPathExtension().lastPathComponent
        let mapURL = URL(fileURLWithPath: concatMapPath!)
        let mapFile = try String(contentsOf: mapURL, encoding: .utf8)
        let mapData: [String] = mapFile.components(separatedBy: .newlines)
        let outDirURL = URL(fileURLWithPath: outputPath)
        try fileManager.createDirectory(at: outDirURL, withIntermediateDirectories: false, attributes: nil)
        Console.print("Trying to split \(inputData.count) bytes from the input file into \(mapData.count) blocks.")
        try inputData.withUnsafeMutableBytes { (inputDataPtr: UnsafeMutablePointer<UInt8>) -> Void in
            var ptr = UnsafeMutableRawPointer(inputDataPtr)
            for i in 0..<mapData.count {
                let blockStr = mapData[i]
                guard let blockSize = Int(blockStr), blockSize > 0 else {
                    Console.print("Found corrupt block size in concat map data! Line:\(i), Block: \(blockStr)", to: .error)
                    return
                }
                let block = Data(bytesNoCopy: ptr, count: blockSize, deallocator: .none)
                let name = String(format: inputName + "_%05d", i)
                let url = outDirURL.appendingPathComponent(name).appendingPathExtension("jpg")
                Console.print("[\(name)] Saving block of \(blockSize) bytes...")
                try block.write(to: url)
                ptr = ptr.advanced(by: blockSize * MemoryLayout<UInt8>.stride)
            }
            Console.print("Output: " + outDirURL.path)
            Console.print("Split operation completed successfully!")
        }
    }
    
    private func execute() throws {
        guard state == .ready else { return }
        switch operation! {
        case .encode:
            Console.print("Execute encoding operation.")
            try encode()
            break
        case .decode:
            Console.print("Execute decoding operation.")
            try decode()
            break
        case .concat:
            Console.print("Execute concat operation.")
            try concat()
            break
        case .split:
            Console.print("Execute split operation.")
            try split()
            break
        default:
            break
        }
    }
    
    private func updateState(_ newState: State) throws {
        if newState != state {
            state = newState
            try run()
        }
    }
    
    func run() throws {
        if state == .waiting {
            let command = Console.getInput().lowercased()
            if command == "y" {
                if !fileManager.isDeletableFile(atPath: outputPath) {
                    Console.print("Cannot delete output file: " + outputPath, to: .error)
                } else {
                    try fileManager.removeItem(atPath: outputPath)
                    try updateState(.ready)
                }
            } else if command == "n" {
                Console.print("Aborted.")
            } else {
                Console.print("Unknown command: `\(command)`")
            }
        } else {
            try execute()
        }
    }
}
