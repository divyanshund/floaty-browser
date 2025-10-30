//
//  main.swift
//  FloatyBrowser
//
//  Application entry point.
//

import Cocoa

// Create the application
let app = NSApplication.shared

// Create and set the delegate
let delegate = AppDelegate()
app.delegate = delegate

// Run the app
_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)

