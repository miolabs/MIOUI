//
//  MIOPageStackTests.swift
//
//  Created by MIO Research Labs on 2026.
//

#if os(macOS)

import XCTest
import SwiftUI
import AppKit
@testable import MIOUI

@MainActor
final class MIOPageStackTests: XCTestCase
{
    private typealias Coordinator = MIOPageStack<Int, Text>.Coordinator

    private func _make_controller(_ coordinator: Coordinator) -> NSPageController
    {
        let controller = MIOPageController()
        controller.view = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 480))
        controller.delegate = coordinator
        return controller
    }

    func testStartShowsTheRootForAnEmptyPath()
    {
        let coordinator = Coordinator(page: { Text("\($0 ?? 0)") })
        let controller = _make_controller(coordinator)

        coordinator.start([], in: controller)

        XCTAssertEqual(controller.arrangedObjects.count, 1)
        XCTAssertEqual(controller.selectedIndex, 0)
    }

    func testStartSelectsTheLastPageOfThePath()
    {
        let coordinator = Coordinator(page: { Text("\($0 ?? 0)") })
        let controller = _make_controller(coordinator)

        coordinator.start([7, 9], in: controller)

        XCTAssertEqual(controller.arrangedObjects.count, 3)
        XCTAssertEqual(controller.selectedIndex, 2)
    }

    func testPagesReceiveTheIDOfTheirLevel()
    {
        var requested_ids: [Int?] = []
        let coordinator = Coordinator(page: { id in
            requested_ids.append(id)
            return Text("\(id ?? 0)")
        })
        let controller = _make_controller(coordinator)

        coordinator.start([7, 9], in: controller)

        for object in controller.arrangedObjects {
            let identifier = coordinator.pageController(controller, identifierFor: object)
            _ = coordinator.pageController(controller, viewControllerForIdentifier: identifier)
        }

        XCTAssertEqual(Set(requested_ids), [nil, 7, 9])
    }

    func testPushAddsAPage()
    {
        let coordinator = Coordinator(page: { Text("\($0 ?? 0)") })
        let controller = _make_controller(coordinator)

        coordinator.start([], in: controller)
        coordinator.show([7], in: controller)

        XCTAssertEqual(controller.arrangedObjects.count, 2)
    }
}

#endif
