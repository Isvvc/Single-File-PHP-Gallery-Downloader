//
//  main.swift
//  Single File PHP Gallery Downloader
//
//  Created by Isaac Lyons on 12/9/20.
//

import Foundation
import ArgumentParser

enum SFPGDError: Error, CustomStringConvertible {
    var description: String {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        }
    }
    
    case invalidURL
}

struct SFPGD: ParsableCommand {
    @Flag(help: "Show verbose printout.")
    var verbose = false

    @Option(name: .shortAndLong, help: "Maximum depth of folders to traverse.")
    var maxDepth: Int?

    @Argument(help: "The URL of the Single File PHP Gallery.")
    var url: String

    mutating func run() throws {
        guard let url = URL(string: url) else {
            throw SFPGDError.invalidURL
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
            
            let images = regex.matches(in: html, options: [], range: range).map { ImageInfo(match: $0, in: html) }
            print(images)
            
            semaphor.signal()
        }.resume()
        
        semaphor.wait()
    }
}

func matchString(_ match: NSTextCheckingResult, matchName: String, in string: String) -> String? {
    let nsrange = match.range(withName: matchName)
    if nsrange.location != NSNotFound,
       let range = Range(nsrange, in: string) {
        return String(string[range])
    }
    return nil
}

struct ImageInfo: CustomDebugStringConvertible {
    var index: Int?
    var link: String?
    var name: String?
    
    init(match: NSTextCheckingResult, in string: String) {
        link = matchString(match, matchName: "imgLink", in: string)
        name = matchString(match, matchName: "imgName", in: string)
        if let indexString = matchString(match, matchName: "imgIndex", in: string),
           let index = Int(indexString) {
            self.index = index
        }
    }
    
    var debugDescription: String {
        var output = ""
        if let index = index {
            output += "[\(index)] "
        }
        if let name = name {
            output += name + ": "
        }
        if let link = link {
            output += link
        }
        return output
    }
    
    func url(baseURL: URL) -> URL? {
        guard let link = link,
              var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else { return nil }
        components.queryItems?.removeAll()
        components.queryItems = [
            .init(name: "cmd", value: "image"),
            .init(name: "sfpg", value: link)
        ]
        return components.url
    }
}

SFPGD.main()
