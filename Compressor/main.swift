//
//  main.swift
//  Compressor
//
//  Created by Andrei Marincas on 1/31/18.
//  Copyright © 2018 Andrei Marincas. All rights reserved.
//

//  Usage example:
//
//  $  /Users/andrei.marincas/Library/Developer/Xcode/DerivedData/Compressor-dxofxmughtzqekgtynwpukghqpaq/Build/Products/Debug/Compressor -encode -i /Users/andrei.marincas/Desktop/Solar/Comp2_00000.jpg -o /Users/andrei.marincas/Desktop/Solar/Comp2_00000-compressed
//  $  /Users/andrei.marincas/Library/Developer/Xcode/DerivedData/Compressor-dxofxmughtzqekgtynwpukghqpaq/Build/Products/Debug/Compressor -decode -i /Users/andrei.marincas/Desktop/Solar/Comp2_00000-compressed -o /Users/andrei.marincas/Desktop/Solar/Comp2_00000-decomp.jpg -no_bytes 29362
//  $  /Users/andrei.marincas/Library/Developer/Xcode/DerivedData/Compressor-dxofxmughtzqekgtynwpukghqpaq/Build/Products/Debug/Compressor -concat -i /Users/andrei.marincas/Desktop/Solar/Comp2 -o /Users/andrei.marincas/Desktop/Solar/Comp2Concat
//  $  /Users/andrei.marincas/Library/Developer/Xcode/DerivedData/Compressor-dxofxmughtzqekgtynwpukghqpaq/Build/Products/Debug/Compressor -split -i /Users/andrei.marincas/Desktop/Solar/Comp2Concat -o /Users/andrei.marincas/Desktop/Solar/Comp2Split -map /Users/andrei.marincas/Desktop/Solar/Comp2Concat-map.data

import Foundation

do {
    try Compressor()?.run()
} catch {
    Console.print(error.localizedDescription, to: .error)
}
