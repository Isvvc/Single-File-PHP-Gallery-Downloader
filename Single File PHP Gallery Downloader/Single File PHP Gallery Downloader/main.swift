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
            
            let pattern = #"imgLink\[(?<imgIndex>[0-9]*)]\s=\s'(?<imgLink>.*)';\simgName\[[0-9]*]\s=\s'(?<imgName>.*)';"#
            let regex = try! NSRegularExpression(pattern: pattern, options: [])
            let range = NSRange(html.startIndex..<html.endIndex, in: html)
            
            for match in regex.matches(in: html, options: [], range: range) {
                let nsrange = match.range(withName: "imgName")
                if nsrange.location != NSNotFound,
                   let range = Range(nsrange, in: html) {
                    print(html[range])
                }
            }
            
            semaphor.signal()
        }.resume()
        
        semaphor.wait()
    }
}

SFPHPGD.main()
