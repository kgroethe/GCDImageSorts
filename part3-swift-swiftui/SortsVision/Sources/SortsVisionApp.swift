//
//  SortsVisionApp.swift
//  SortsVision
//
//  Part 4 of the GCDImageSorts series. Parts 1 to 3 scrambled a 2D image and
//  sorted it back together; this does the same to a voxel structure, in a full
//  immersive space so the only thing in the room is the structure.
//

import SwiftUI

@main
struct SortsVisionApp: App {
    @State private var runner = VolumeRunner()
    @State private var immersion: ImmersionStyle = .full

    var body: some Scene {
        WindowGroup(id: "controls") {
            ControlPanel()
                .environment(runner)
        }
        .defaultSize(width: 560, height: 320)

        // .full replaces passthrough entirely, so the background goes black and
        // the structure is the only lit thing in view.
        ImmersiveSpace(id: "space") {
            ImmersiveVolumeView()
                .environment(runner)
        }
        .immersionStyle(selection: $immersion, in: .full)
    }
}
