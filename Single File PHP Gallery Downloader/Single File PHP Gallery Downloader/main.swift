//
//  main.swift
//  Single File PHP Gallery Downloader
//
//  Created by Isaac Lyons on 12/9/20.
//

import Foundation
import ArgumentParser

enum SFPHPGDError: Error {
    case invalidURL
}

struct SFPHPGD: ParsableCommand {
    @Flag(help: "Show verbose printout.")
    var verbose = false

    @Option(name: .shortAndLong, help: "Maximum depth of folders to traverse.")
    var maxDepth: Int?

    @Argument(help: "The URL of the Single File PHP Gallery.")
    var url: String

    mutating func run() throws {
        guard let url = URL(string: url) else {
            throw SFPHPGDError.invalidURL
        }
        
        let semaphor = DispatchSemaphore(value: 0)
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            guard error == nil,
                  let data = data,
                  let html = String(data: data, encoding: .utf8) else {
                semaphor.signal()
                return
            }
            
            print(html)
            semaphor.signal()
        }.resume()
        
        semaphor.wait()
    }
}

SFPHPGD.main()
