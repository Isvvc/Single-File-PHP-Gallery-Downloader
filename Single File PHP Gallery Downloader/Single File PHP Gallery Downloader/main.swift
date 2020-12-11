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
        case .invalidOutput:
            return "Invalid output directory"
        case .outputDirectoryIsFile(let dir):
            return "\(dir) file exists."
        }
    }
    
    case invalidURL
    case invalidOutput
    case outputDirectoryIsFile(String)
}

struct SFPGD: ParsableCommand {
    @Flag(name: .shortAndLong, help: "Show verbose printout.")
    var verbose = false
    
    @Flag(name: .shortAndLong, help: "Recurively download subdirectories. Is overridden by --depth.")
    var recursive = false

    @Option(name: .shortAndLong, help: "Maximum depth of folders to traverse. Overrides --recursive.")
    var depth: Int?
    
    @Option(name: .shortAndLong, help: "Maximum number of images to save, including existing files.")
    var count: Int?
    
    @Option(name: .shortAndLong, help: "Output directory.")
    var output: String?
    
    @Option(name: .shortAndLong, help: "Limit of number of new images to download.")
    var limit: Int?

    @Argument(help: "The URL of the Single File PHP Gallery.")
    var url: String

    mutating func run() throws {
        guard let url = URL(string: url) else {
            throw SFPGDError.invalidURL
        }
        let output = URL(fileURLWithPath: self.output ?? FileManager.default.currentDirectoryPath)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: output.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw SFPGDError.invalidOutput
        }
        
        if depth == nil && recursive {
            depth = .max
        }
        
        var saved = 0
        var downloaded = 0
        
        try download(url: url, baseOutput: output, saved: &saved, downloaded: &downloaded)
        
        print("Done!")
    }
    
    mutating func download(url: URL, baseOutput: URL, saved: inout Int, downloaded: inout Int, depth: Int = 0) throws {
        let semaphor = DispatchSemaphore(value: 0)
        
        var output = baseOutput
        var images: [ImageInfo] = []
        var dirs: [ImageInfo] = []
        var thisDir: ImageInfo?
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            guard error == nil,
                  let data = data,
                  let html = String(data: data, encoding: .utf8) else {
                semaphor.signal()
                return
            }
            
            // Images are listed as imgLink, imgName, then imgInfo (which we don't need).
            let imgPattern = #"imgLink\[(?<index>[0-9]*)]\s=\s'(?<link>.*)';\simgName\[[0-9]*]\s=\s'(?<name>.*)';"#
            let imgRegex = try! NSRegularExpression(pattern: imgPattern, options: [])
            let range = NSRange(html.startIndex..<html.endIndex, in: html)
            
            images = imgRegex.matches(in: html, options: [], range: range).map { ImageInfo(match: $0, in: html) }
            
            // The current directory is listed as dirLink then dirName.
            let thisDirPattern = #"dirLink\[(?<index>[0-9]*)]\s=\s'(?<link>.*)';\sdirName\[[0-9]*]\s=\s'(?<name>.*)';"#
            let thisDirRegex = try! NSRegularExpression(pattern: thisDirPattern, options: [])
            
            thisDir = thisDirRegex.matches(in: html, options: [], range: range).map { ImageInfo(match: $0, in: html, isDir: true) }.first
            
            // Subdirectory links are listed as dirName then dirLink.
            let dirPattern = #"dirName\[(?<index>[0-9]*)]\s=\s'(?<name>.*)';\sdirLink\[[0-9]*]\s=\s'(?<link>.*)';"#
            let dirRegex = try! NSRegularExpression(pattern: dirPattern, options: [])
            
            dirs = dirRegex.matches(in: html, options: [], range: range).map { ImageInfo(match: $0, in: html, isDir: true) }
            
            semaphor.signal()
        }.resume()
        
        semaphor.wait()
        
        if verbose {
            print("\(images.count) images found.")
        }
        
        if let count = count {
            if images.count > count - saved {
                images.removeLast(images.count - (count - saved))
            }
        }
        
        if let thisDir = thisDir,
           let dirName = thisDir.name {
            let url = output.appendingPathComponent(dirName)
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) {
                if !isDirectory.boolValue {
                    throw SFPGDError.outputDirectoryIsFile(url.path)
                }
            } else {
                try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            }
            
            output = url
            
            if verbose {
                print("Saving to \(output.lastPathComponent)/")
            }
        }
        
        let fileMananger = FileManager.default
        images.forEach { image in
            guard let name = image.name ?? image.link,
                  let url = image.url(baseURL: url) else { return }
            
            let namePath = output.appendingPathComponent(name)
            
            // Check if the file already exists
            
            // Unfortunately, SFPG does not tell you the file format of images. It
            // just gives you raw data and it's up to your browser to interpret the
            // image type. We have to just check if an image file of any the supported
            // formats exists, since we don't know which it will be until it is downloaded.

            for fileExtension in ["jpg", "png", "gif"] {
                if fileMananger.fileExists(atPath: namePath.appendingPathExtension(fileExtension).path) {
                    if verbose {
                        print("File \(name).\(fileExtension) already exists. Skipping.")
                    }
                    return
                }
            }
            
            if verbose {
                print("Downloading \(name)...")
            }
            URLSession.shared.dataTask(with: url) { data, response, error in
                guard error == nil,
                      let data = data else {
                    semaphor.signal()
                    return
                }
                
                // Get the image type
                
                let fileExtension: String?
                
                var b: UInt8 = 0
                data.copyBytes(to: &b, count: 1)
                
                switch b {
                case 0xFF:
                    fileExtension = "jpg"
                case 0x89:
                    fileExtension = "png"
                case 0x47:
                    fileExtension = "gif"
                default:
                    fileExtension = nil
                }
                
                // Save image to file
                var path = namePath
                if let fileExtension = fileExtension {
                    path = namePath.appendingPathExtension(fileExtension)
                }
                
                do {
                    try data.write(to: path)
                } catch {
                    NSLog("\(error)")
                }
                
                semaphor.signal()
            }.resume()
            semaphor.wait()
            downloaded += 1
        }
        saved += images.count
        
        if saved < count ?? .max,
           depth < self.depth ?? 0 {
            for dir in dirs {
                guard let url = dir.url(baseURL: url) else { continue }
                try download(url: url, baseOutput: output, saved: &saved, downloaded: &downloaded, depth: depth + 1)
                if let count = count,
                   saved >= count {
                    break
                }
            }
        }
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
    var dir: Bool
    
    init(match: NSTextCheckingResult, in string: String, isDir: Bool = false) {
        link = matchString(match, matchName: "link", in: string)
        name = matchString(match, matchName: "name", in: string)
        if let indexString = matchString(match, matchName: "index", in: string),
           let index = Int(indexString) {
            self.index = index
        }
        dir = isDir
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
        if !dir {
            components.queryItems?.append(.init(name: "cmd", value: "image"))
        }
        components.queryItems?.append(.init(name: "sfpg", value: link))
        return components.url
    }
}

SFPGD.main()
