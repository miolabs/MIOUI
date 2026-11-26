//
//  MIOPageStack.swift
//
//  Created by MIO Research Labs on 2026.
//

#if os(macOS)

import SwiftUI
import AppKit

/// A stack of pages that slide horizontally, driven by a path, for macOS.
///
/// It does the job of `NavigationStack(path:)` inside a column of a macOS window,
/// where `NavigationStack` takes over the window toolbar and title. The pages are
/// SwiftUI views hosted in an `NSPageController`, which provides the slide.
///
/// The path is the only source of truth: appending an ID pushes a page, removing
/// IDs pops. The stack never changes the path by itself.
///
/// ```swift
/// MIOPageStack(path: $path) { category_id in
///     CategoryList(categoryID: category_id)
/// }
/// ```
///
/// The pages receive the environment of the stack, and the path can hold any
/// `Hashable` type.
///
/// ## Other platforms
///
/// The stack only exists on macOS. On iOS, use `NavigationStack(path:)` with
/// the same path:
///
/// ```swift
/// #if os(macOS)
/// MIOPageStack(path: $path) { id in
///     Level(id: id)
/// }
/// #else
/// NavigationStack(path: $path) {
///     Level(id: nil)
///         .navigationDestination(for: UUID.self) { id in
///             Level(id: id)
///         }
/// }
/// #endif
/// ```
///
/// - Important: Two IDs in the same path must not have the same
///   `String(describing:)`, since that text is what tells the pages apart.
public struct MIOPageStack<ID: Hashable, Page: View>: NSViewControllerRepresentable
{
    /// The IDs of the pages on top of the root, from first pushed to last.
    @Binding private var _path: [ID]

    /// Builds the page of an ID, or the root page for `nil`.
    private let _page: (ID?) -> Page

    /// Creates a stack that shows the root page plus one page per ID in the path.
    ///
    /// - Parameters:
    ///   - path: The IDs of the pushed pages. Change it to push or pop.
    ///   - page: Builds the page of an ID. It receives `nil` for the root page.
    public init(path: Binding<[ID]>, @ViewBuilder page: @escaping (ID?) -> Page)
    {
        __path = path
        _page = page
    }

    /// Creates the object that owns the pages and answers the page controller.
    public func makeCoordinator() -> Coordinator
    {
        Coordinator(page: _page)
    }

    /// Creates the page controller, already showing the last page of the path
    /// without animating towards it.
    public func makeNSViewController(context: Context) -> NSPageController
    {
        let controller = MIOPageController()
        controller.view = NSView()
        controller.delegate = context.coordinator
        controller.transitionStyle = .horizontalStrip
        context.coordinator.environment = context.environment
        context.coordinator.start(_path, in: controller)
        return controller
    }

    /// Animates to the current path and gives every page its new content.
    ///
    /// The pages live in their own hosting controllers, outside this view's
    /// SwiftUI hierarchy, so they neither redraw nor receive the environment by
    /// themselves: both are handed over here. The content is replaced on the
    /// next main-queue turn because this method runs during a layout pass, and
    /// replacing a hosted view at that point makes AppKit warn about laying out
    /// a hosting view reentrantly.
    public func updateNSViewController(_ controller: NSPageController, context: Context)
    {
        context.coordinator.page = _page
        context.coordinator.environment = context.environment
        context.coordinator.show(_path, in: controller)

        let coordinator = context.coordinator
        DispatchQueue.main.async {
            coordinator.refresh()
        }
    }

    // MARK: - Coordinator

    /// Owns the hosted pages and is the delegate of the page controller.
    ///
    /// The page controller only knows pages by a string identifier, so this
    /// keeps the translation between those identifiers, the IDs of the path and
    /// the hosting controllers.
    @MainActor
    public final class Coordinator: NSObject, NSPageControllerDelegate
    {
        /// The identifier of the root page, the one page with no ID in the path.
        static var rootIdentifier: String { "root" }

        /// Builds the page of an ID. Replaced on every update, since the closure
        /// captures the caller's current state.
        var page: (ID?) -> Page

        /// The environment of the stack, applied to every page so that values
        /// such as the managed object context reach them.
        var environment = EnvironmentValues()

        /// The identifiers of the pages the path asks for, root first. Compared
        /// with each new path to know whether anything has to move.
        private var _shown_identifiers = [Coordinator.rootIdentifier]

        /// The ID behind each page identifier, to call `page` with it.
        private var _ids_by_identifier: [String: ID] = [:]

        /// The hosting controller of each page, kept so that a page keeps its
        /// state while it is in the path and the controller can reuse it.
        private var _hosting_controllers: [String: NSHostingController<AnyView>] = [:]

        init(page: @escaping (ID?) -> Page)
        {
            self.page = page
        }

        /// Shows the last page of the initial path, without animation.
        func start(_ initial_path: [ID], in controller: NSPageController)
        {
            _shown_identifiers = _identifiers(for: initial_path)
            controller.arrangedObjects = _shown_identifiers
            controller.selectedIndex = _shown_identifiers.count - 1
        }

        /// Rebuilds the content of every hosted page with the current `page`
        /// closure and environment.
        func refresh()
        {
            for (identifier, hosting_controller) in _hosting_controllers {
                hosting_controller.rootView = _root_view(for: identifier)
            }
        }

        /// Slides to the last page of the new path.
        ///
        /// On a push, the new page is added before the animation so there is
        /// something to slide to. On a pop, the pages being left stay until the
        /// animation ends, or they would vanish under it, and are removed in
        /// `_trim`. `completeTransition` is what the page controller requires
        /// after an animated change to put the real page in place of its snapshot.
        func show(_ new_path: [ID], in controller: NSPageController)
        {
            let identifiers = _identifiers(for: new_path)
            guard identifiers != _shown_identifiers else { return }

            let is_push = identifiers.count > _shown_identifiers.count
            let current_index = controller.selectedIndex
            _shown_identifiers = identifiers

            if is_push {
                controller.arrangedObjects = identifiers
                controller.selectedIndex = current_index
            }

            NSAnimationContext.runAnimationGroup { _ in
                controller.animator().selectedIndex = identifiers.count - 1
            } completionHandler: {
                MainActor.assumeIsolated {
                    controller.completeTransition()
                    self._trim(controller)
                }
            }
        }

        /// The page identifiers of a path, root first, remembering the ID of each.
        private func _identifiers(for path: [ID]) -> [String]
        {
            var identifiers = [Coordinator.rootIdentifier]

            for id in path {
                let identifier = "id:\(String(describing: id))"
                _ids_by_identifier[identifier] = id
                identifiers.append(identifier)
            }

            return identifiers
        }

        /// Drops the pages that are no longer in the path, once nothing is
        /// animating over them.
        private func _trim(_ controller: NSPageController)
        {
            _hosting_controllers = _hosting_controllers.filter { _shown_identifiers.contains($0.key) }
            _ids_by_identifier = _ids_by_identifier.filter { _shown_identifiers.contains($0.key) }

            guard controller.arrangedObjects.count != _shown_identifiers.count else { return }
            controller.arrangedObjects = _shown_identifiers
            controller.selectedIndex = _shown_identifiers.count - 1
        }

        /// The content of a page, type-erased so that one hosting controller
        /// type serves every page, with the stack's environment applied.
        private func _root_view(for identifier: String) -> AnyView
        {
            AnyView(page(_ids_by_identifier[identifier]).environment(\.self, environment))
        }

        // MARK: - NSPageControllerDelegate

        /// The identifier of a page. The arranged objects are the identifiers
        /// themselves.
        public func pageController(_ pageController: NSPageController, identifierFor object: Any) -> NSPageController.ObjectIdentifier
        {
            object as? String ?? Coordinator.rootIdentifier
        }

        /// Takes back a page that the page controller kept after it left the path.
        ///
        /// The page controller keeps its own cache of view controllers and can
        /// show one again without asking for it. Such a page is no longer in
        /// `_hosting_controllers`, so it would miss every refresh and show the
        /// content it had when it was popped.
        public func pageController(_ pageController: NSPageController, prepare viewController: NSViewController, with object: Any?)
        {
            guard let identifier = object as? String, let hosting_controller = viewController as? NSHostingController<AnyView> else { return }
            guard _hosting_controllers[identifier] !== hosting_controller else { return }

            _hosting_controllers[identifier] = hosting_controller
            hosting_controller.rootView = _root_view(for: identifier)
        }

        /// The hosting controller of a page, created the first time it is asked for.
        ///
        /// Its sizing options are emptied so the page takes the size of the
        /// stack instead of imposing its own ideal size on it.
        public func pageController(_ pageController: NSPageController, viewControllerForIdentifier identifier: NSPageController.ObjectIdentifier) -> NSViewController
        {
            if let hosting_controller = _hosting_controllers[identifier] { return hosting_controller }

            let hosting_controller = NSHostingController(rootView: _root_view(for: identifier))
            _hosting_controllers[identifier] = hosting_controller
            hosting_controller.sizingOptions = []
            hosting_controller.view.frame = pageController.view.bounds
            hosting_controller.view.autoresizingMask = [.width, .height]
            return hosting_controller
        }
    }
}

/// The page controller behind `MIOPageStack`.
final class MIOPageController: NSPageController
{
    /// Keeps the visible page as large as the stack when the stack is resized.
    override func viewDidLayout()
    {
        super.viewDidLayout()
        selectedViewController?.view.frame = view.bounds
    }

    /// Ignores scrolling, which the page controller would otherwise turn into
    /// a swipe between pages. A swipe would change the page without changing
    /// the path, and the path has to stay the only source of truth.
    override func scrollWheel(with event: NSEvent)
    {
    }
}

#if DEBUG

private struct MIOPageStackPreview: View
{
    @State var path: [Int]

    var body: some View
    {
        MIOPageStack(path: $path) { level in
            VStack(spacing: 12) {
                Text(level.map { "Level \($0)" } ?? "Root")
                    .font(.title2)

                Button("Push") {
                    path.append(path.count + 1)
                }

                Button("Pop") {
                    path.removeLast()
                }
                .disabled(path.isEmpty)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 320, height: 480)
    }
}

#Preview("Root")
{
    MIOPageStackPreview(path: [])
}

#Preview("Two levels in")
{
    MIOPageStackPreview(path: [1, 2])
}

#endif

#endif
