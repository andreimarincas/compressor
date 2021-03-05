//
//  Console.swift
//  Compressor
//
//  Created by Andrei Marincas on 1/31/18.
//  Copyright © 2018 Andrei Marincas. All rights reserved.
//

import Foundation

enum OutputType {
    case error
    case standard
}

class Console {
    
    private static let `default` = Console()
    
    private func log(_ message: String, to output: OutputType) {
        switch output {
        case .standard:
            print("\(message)")
        case .error:
            fputs("Error: \(message)\n", stderr)
        }
    }
    
    class func print(_ message: String, to output: OutputType = .standard) {
        Console.default.log(message, to: output)
    }
    
    class func printUsage() {
        let path = CommandLine.arguments.first!
        let name = (path as NSString).lastPathComponent
        Console.print("Usage: " + name + " [-encode|-decode|-concat|-split] [-i input_file] [-o output_file] [-no_bytes bytes_count_decode] [-map concat_map]")
    }
    
    class func getInput() -> String {
        let keyboard = FileHandle.standardInput
        let inputData = keyboard.availableData
        let strData = String(data: inputData, encoding: String.Encoding.utf8)!
        return strData.trimmingCharacters(in: CharacterSet.newlines)
    }
}
