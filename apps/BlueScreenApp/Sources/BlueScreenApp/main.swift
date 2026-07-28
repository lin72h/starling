// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
import FlutterMacOSBridge
#elseif os(Linux)
import FlutterEmbedderBridge
import FlutterDRMBridge
import GLFWBridge
import Foundation
import Glibc
#endif

import Flutter
import FlutterSwiftBridge
import SwiftRuntime

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - Demo Helpers
// ═══════════════════════════════════════════════════════════════════════════════

/// Section header with title
class SectionHeader: StatelessWidget {
    let title: String
    init(_ title: String) {
        self.title = title
        super.init()
    }
    override func build(_ context: any BuildContext) -> Widget {
        let theme = FluentTheme.of(context)
        return Padding(
            padding: EdgeInsets(top: 16, bottom: 8),
            child: Text(title, style: theme.typography.subtitle)
        )
    }
}

/// A labeled row: "Label:  [widget]"
class LabeledControl: StatelessWidget {
    let label: String
    let child: Widget
    init(_ label: String, child: Widget) {
        self.label = label
        self.child = child
        super.init()
    }
    override func build(_ context: any BuildContext) -> Widget {
        let theme = FluentTheme.of(context)
        return Padding(
            padding: EdgeInsets(bottom: 12),
            child: Row(
                children: [
                    SizedBox(width: 160, child: Text(label, style: theme.typography.body)),
                    Expanded(child: child),
                ]
            )
        )
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - Home Page
// ═══════════════════════════════════════════════════════════════════════════════

class HomePage: StatelessWidget {
    override func build(_ context: any BuildContext) -> Widget {
        return ScaffoldPage.scrollable(
            header: PageHeader(title: Text("Welcome to Flutter Swift")),
            children: [
                Text("A complete Flutter UI framework ported to Swift, running without the Dart VM."),
                SizedBox(height: 24),
                SectionHeader("Features"),
                Text("Full widget tree with StatelessWidget & StatefulWidget"),
                Text("Fluent UI design system controls"),
                Text("Buttons, Inputs, Sliders, Checkboxes"),
                Text("Navigation with NavigationView & TabView"),
                Text("Flyouts, Menus, Dialogs"),
                Text("Animations with AnimationController"),
                Text("Custom painting with Canvas API"),
                Text("Scrollable content with SingleChildScrollView"),
                SizedBox(height: 24),
                Text("Use the navigation pane on the left to explore different control categories."),
            ]
        )
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - Buttons Page
// ═══════════════════════════════════════════════════════════════════════════════

class ButtonsPage: StatefulWidget {
    override func createState() -> State<StatefulWidget> { _ButtonsPageState() }
}

class _ButtonsPageState: State<StatefulWidget> {
    var toggleChecked = false

    override func build(_ context: any BuildContext) -> Widget {
        return ScaffoldPage.scrollable(
            header: PageHeader(title: Text("Buttons")),
            children: [
                SectionHeader("Standard Buttons"),
                Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                        Button(onPressed: {}, child: Text("Button")),
                        FilledButton(onPressed: {}, child: Text("Filled")),
                        HyperlinkButton(onPressed: {}, child: Text("Hyperlink")),
                        IconButton(icon: Text("\u{2605}"), onPressed: {}),
                    ]
                ),

                SectionHeader("Disabled Buttons"),
                Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                        Button(child: Text("Disabled")),
                        FilledButton(child: Text("Disabled Filled")),
                    ]
                ),

                SectionHeader("Toggle Button"),
                ToggleButton(
                    checked: toggleChecked,
                    onChanged: { [self] val in setState { toggleChecked = val } },
                    child: Text("Toggle Me")
                ),

                SectionHeader("DropDown Button"),
                DropDownButton(
                    title: Text("Options"),
                    items: [
                        MenuFlyoutItem(text: Text("Option 1"), onPressed: {}),
                        MenuFlyoutItem(text: Text("Option 2"), onPressed: {}),
                        MenuFlyoutSeparator(),
                        MenuFlyoutItem(text: Text("Option 3"), onPressed: {}),
                    ]
                ),

                SectionHeader("Split Button"),
                SplitButton(
                    child: Padding(
                        padding: EdgeInsets(left: 12, top: 6, right: 12, bottom: 6),
                        child: Text("Send")
                    ),
                    flyout: FlyoutContent(
                        child: Column(
                            mainAxisSize: .min,
                            crossAxisAlignment: .start,
                            children: [
                                FlyoutListTile(onPressed: {}, text: Text("Send now")),
                                FlyoutListTile(onPressed: {}, text: Text("Schedule")),
                            ]
                        )
                    ),
                    onPressed: {}
                ),
            ]
        )
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - Inputs Page
// ═══════════════════════════════════════════════════════════════════════════════

class InputsPage: StatefulWidget {
    override func createState() -> State<StatefulWidget> { _InputsPageState() }
}

class _InputsPageState: State<StatefulWidget> {
    var checkboxValue: Bool? = true
    var switchValue = false
    var sliderValue: Double = 40.0
    var radioValue = 1
    var ratingValue: Double = 3.0

    override func build(_ context: any BuildContext) -> Widget {
        return ScaffoldPage.scrollable(
            header: PageHeader(title: Text("Inputs")),
            children: [
                SectionHeader("Checkbox"),
                LabeledControl("Two-state", child:
                    Checkbox(
                        checked: checkboxValue,
                        onChanged: { [self] val in setState { checkboxValue = val } },
                        content: Text("I agree to the terms")
                    )
                ),

                SectionHeader("Toggle Switch"),
                LabeledControl("On / Off", child:
                    ToggleSwitch(
                        checked: switchValue,
                        onChanged: { [self] val in setState { switchValue = val } },
                        content: Text(switchValue ? "On" : "Off")
                    )
                ),

                SectionHeader("Slider"),
                LabeledControl("Value: \(Int(sliderValue))", child:
                    Slider(
                        value: sliderValue,
                        onChanged: { [self] val in setState { sliderValue = val } },
                        min: 0,
                        max: 100,
                        divisions: 20
                    )
                ),

                SectionHeader("Radio Buttons"),
                RadioButton<Int>(
                    value: 1,
                    groupValue: radioValue,
                    onChanged: { [self] val in
                        if let v = val { setState { radioValue = v } }
                    },
                    content: Text("Option 1")
                ),
                SizedBox(height: 8),
                RadioButton<Int>(
                    value: 2,
                    groupValue: radioValue,
                    onChanged: { [self] val in
                        if let v = val { setState { radioValue = v } }
                    },
                    content: Text("Option 2")
                ),
                SizedBox(height: 8),
                RadioButton<Int>(
                    value: 3,
                    groupValue: radioValue,
                    onChanged: { [self] val in
                        if let v = val { setState { radioValue = v } }
                    },
                    content: Text("Option 3")
                ),

                SectionHeader("Rating Bar"),
                LabeledControl("Rating: \(ratingValue)", child:
                    RatingBar(
                        rating: ratingValue,
                        onChanged: { [self] val in setState { ratingValue = val } }
                    )
                ),
            ]
        )
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - Text & Form Page
// ═══════════════════════════════════════════════════════════════════════════════

class TextFormPage: StatefulWidget {
    override func createState() -> State<StatefulWidget> { _TextFormPageState() }
}

class _TextFormPageState: State<StatefulWidget> {
    let textController = TextEditingController()
    let passwordController = TextEditingController()
    var numberValue: Double? = 42.0
    var comboValue: String? = nil

    override func build(_ context: any BuildContext) -> Widget {
        return ScaffoldPage.scrollable(
            header: PageHeader(title: Text("Text & Form")),
            children: [
                SectionHeader("TextBox"),
                SizedBox(
                    width: 300,
                    child: FluentTextBox(
                        controller: textController,
                        placeholderText: "Type something..."
                    )
                ),

                SectionHeader("PasswordBox"),
                SizedBox(
                    width: 300,
                    child: PasswordBox(
                        controller: passwordController,
                        placeholderText: "Enter password",
                        revealMode: .peek
                    )
                ),

                SectionHeader("NumberBox"),
                SizedBox(
                    width: 200,
                    child: NumberBox(
                        value: numberValue,
                        onChanged: { [self] val in setState { numberValue = val } },
                        min: 0,
                        max: 100,
                        smallChange: 1
                    )
                ),

                SectionHeader("ComboBox"),
                SizedBox(
                    width: 250,
                    child: ComboBox<String>(
                        value: comboValue,
                        items: [
                            ComboBoxItem(value: "Apple", child: Text("Apple")),
                            ComboBoxItem(value: "Banana", child: Text("Banana")),
                            ComboBoxItem(value: "Cherry", child: Text("Cherry")),
                            ComboBoxItem(value: "Date", child: Text("Date")),
                        ],
                        onChanged: { [self] val in setState { comboValue = val } },
                        placeholder: Text("Select a fruit")
                    )
                ),

                SectionHeader("AutoSuggestBox"),
                SizedBox(
                    width: 300,
                    child: AutoSuggestBox(
                        items: [
                            AutoSuggestBoxItem(value: "Apple"),
                            AutoSuggestBoxItem(value: "Banana"),
                            AutoSuggestBoxItem(value: "Cherry"),
                            AutoSuggestBoxItem(value: "Date"),
                            AutoSuggestBoxItem(value: "Elderberry"),
                            AutoSuggestBoxItem(value: "Fig"),
                            AutoSuggestBoxItem(value: "Grape"),
                        ],
                        placeholderText: "Search fruits..."
                    )
                ),
            ]
        )
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - Surfaces Page
// ═══════════════════════════════════════════════════════════════════════════════

class SurfacesPage: StatefulWidget {
    override func createState() -> State<StatefulWidget> { _SurfacesPageState() }
}

class _SurfacesPageState: State<StatefulWidget> {
    var progressValue: Double = 65.0

    override func build(_ context: any BuildContext) -> Widget {
        let theme = FluentTheme.of(context)
        return ScaffoldPage.scrollable(
            header: PageHeader(title: Text("Surfaces")),
            children: [
                SectionHeader("Card"),
                Card(
                    child: Column(
                        crossAxisAlignment: .start,
                        children: [
                            Text("This is a Card", style: theme.typography.bodyStrong),
                            SizedBox(height: 8),
                            Text("Cards contain related content and actions.",
                                 style: theme.typography.body),
                        ]
                    )
                ),

                SectionHeader("Acrylic"),
                SizedBox(
                    width: 300,
                    height: 80,
                    child: Acrylic(
                        child: Center(
                            child: Text("Acrylic Surface", style: theme.typography.bodyStrong)
                        )
                    )
                ),

                SectionHeader("InfoBar"),
                InfoBar(
                    title: Text("Information"),
                    content: Text("This is an informational message."),
                    severity: .info
                ),
                SizedBox(height: 8),
                InfoBar(
                    title: Text("Success!"),
                    content: Text("Operation completed."),
                    severity: .success
                ),
                SizedBox(height: 8),
                InfoBar(
                    title: Text("Warning"),
                    content: Text("Please check your input."),
                    severity: .warning
                ),

                SectionHeader("Progress Indicators"),
                LabeledControl("Determinate bar", child:
                    ProgressBar(value: progressValue)
                ),
                LabeledControl("Indeterminate bar", child:
                    ProgressBar()
                ),
                LabeledControl("Ring", child:
                    SizedBox(square: 36, child: ProgressRing(value: progressValue))
                ),
                LabeledControl("Adjust", child:
                    Slider(
                        value: progressValue,
                        onChanged: { [self] val in setState { progressValue = val } },
                        min: 0,
                        max: 100
                    )
                ),

                SectionHeader("Expander"),
                Expander(
                    header: Text("Click to expand"),
                    content: Text("This content is revealed when the expander is open."),
                    initiallyExpanded: false
                ),

                SectionHeader("InfoBadge"),
                Wrap(
                    spacing: 16,
                    children: [
                        InfoBadge(key: nil, source: Text("3")),
                        InfoBadge(key: nil, source: Text("!"), color: Color(0xFFFF9800)),
                        InfoBadge(key: nil, source: Text("\u{2713}"), color: Color(0xFF4CAF50)),
                    ]
                ),
            ]
        )
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - CommandBar Page
// ═══════════════════════════════════════════════════════════════════════════════

class CommandBarPage: StatelessWidget {
    override func build(_ context: any BuildContext) -> Widget {
        return ScaffoldPage.scrollable(
            header: PageHeader(title: Text("CommandBar")),
            children: [
                SectionHeader("Basic CommandBar"),
                CommandBar(
                    primaryItems: [
                        CommandBarButton(icon: Text("+"), label: Text("New"), onPressed: {}),
                        CommandBarButton(icon: Text("\u{270E}"), label: Text("Edit"), onPressed: {}),
                        CommandBarSeparator(),
                        CommandBarButton(icon: Text("\u{2702}"), label: Text("Cut"), onPressed: {}),
                        CommandBarButton(icon: Text("\u{2398}"), label: Text("Copy"), onPressed: {}),
                        CommandBarButton(icon: Text("\u{2399}"), label: Text("Paste"), onPressed: {}),
                    ]
                ),
                SizedBox(height: 24),

                SectionHeader("With Overflow"),
                CommandBar(
                    primaryItems: [
                        CommandBarButton(icon: Text("\u{2B}"), label: Text("Add"), onPressed: {}),
                        CommandBarButton(icon: Text("\u{2212}"), label: Text("Remove"), onPressed: {}),
                    ],
                    secondaryItems: [
                        CommandBarButton(icon: Text("S"), label: Text("Save"), onPressed: {}),
                        CommandBarButton(icon: Text("P"), label: Text("Print"), onPressed: {}),
                        CommandBarButton(label: Text("Export"), onPressed: {}),
                    ]
                ),
            ]
        )
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - Dialogs & Flyouts Page
// ═══════════════════════════════════════════════════════════════════════════════

class DialogsPage: StatelessWidget {
    override func build(_ context: any BuildContext) -> Widget {
        return ScaffoldPage.scrollable(
            header: PageHeader(title: Text("Dialogs & Flyouts")),
            children: [
                SectionHeader("Content Dialog"),
                FilledButton(
                    onPressed: {
                        showDialog(context: context, barrierDismissible: true, builder: { ctx in
                            ContentDialog(
                                title: Text("Delete file?"),
                                content: Text("This action cannot be undone."),
                                actions: [
                                    Button(
                                        onPressed: { Navigator.pop(ctx) },
                                        child: Text("Cancel")
                                    ),
                                    FilledButton(
                                        onPressed: { Navigator.pop(ctx) },
                                        child: Text("Delete")
                                    ),
                                ]
                            )
                        })
                    },
                    child: Text("Show Dialog")
                ),

                SectionHeader("Tooltip"),
                Tooltip(
                    message: "This is a tooltip!",
                    child: Button(onPressed: {}, child: Text("Hover over me"))
                ),

                SectionHeader("Flyout"),
                FlyoutDemo(),

                SectionHeader("MenuFlyout"),
                MenuFlyoutDemo(),
            ]
        )
    }
}

class FlyoutDemo: StatefulWidget {
    override func createState() -> State<StatefulWidget> { _FlyoutDemoState() }
}

class _FlyoutDemoState: State<StatefulWidget> {
    let flyoutController = FlyoutController()

    override func build(_ context: any BuildContext) -> Widget {
        return FlyoutTarget(
            controller: flyoutController,
            child: Button(
                onPressed: { [self] in
                    flyoutController.showFlyout(
                        builder: { _ in
                            FlyoutContent(
                                child: Column(
                                    mainAxisSize: .min,
                                    crossAxisAlignment: .start,
                                    children: [
                                        Text("This is a flyout"),
                                        SizedBox(height: 8),
                                        Button(
                                            onPressed: { [self] in flyoutController.closeFlyout() },
                                            child: Text("Close")
                                        ),
                                    ]
                                )
                            )
                        },
                        barrierDismissible: true
                    )
                },
                child: Text("Show Flyout")
            )
        )
    }
}

class MenuFlyoutDemo: StatefulWidget {
    override func createState() -> State<StatefulWidget> { _MenuFlyoutDemoState() }
}

class _MenuFlyoutDemoState: State<StatefulWidget> {
    let flyoutController = FlyoutController()

    override func build(_ context: any BuildContext) -> Widget {
        return FlyoutTarget(
            controller: flyoutController,
            child: Button(
                onPressed: { [self] in
                    flyoutController.showFlyout(
                        builder: { _ in
                            MenuFlyout(
                                items: [
                                    MenuFlyoutItem(text: Text("Cut"), onPressed: {}),
                                    MenuFlyoutItem(text: Text("Copy"), onPressed: {}),
                                    MenuFlyoutItem(text: Text("Paste"), onPressed: {}),
                                    MenuFlyoutSeparator(),
                                    MenuFlyoutItem(text: Text("Select All"), onPressed: {}),
                                ]
                            )
                        },
                        barrierDismissible: true
                    )
                },
                child: Text("Show Menu")
            )
        )
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - TeachingTip Page
// ═══════════════════════════════════════════════════════════════════════════════

class TeachingTipPage: StatefulWidget {
    override func createState() -> State<StatefulWidget> { _TeachingTipPageState() }
}

class _TeachingTipPageState: State<StatefulWidget> {
    var showTip = false

    override func build(_ context: any BuildContext) -> Widget {
        return ScaffoldPage.scrollable(
            header: PageHeader(title: Text("TeachingTip")),
            children: [
                SectionHeader("Teaching Tip"),
                Text("Teaching tips provide contextual information about UI features."),
                SizedBox(height: 16),
                TeachingTip(
                    target: FilledButton(
                        onPressed: { [self] in setState { showTip = !showTip } },
                        child: Text(showTip ? "Hide Tip" : "Show Tip")
                    ),
                    title: Text("New Feature"),
                    subtitle: Text("Check this out"),
                    isOpen: showTip,
                    onClose: { [self] in setState { showTip = false } },
                    body: Text("This button demonstrates the TeachingTip widget, which can show contextual help."),
                    actions: [
                        Button(
                            onPressed: { [self] in setState { showTip = false } },
                            child: Text("Got it!")
                        ),
                    ]
                ),
            ]
        )
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - MenuBar Page
// ═══════════════════════════════════════════════════════════════════════════════

class MenuBarPage: StatelessWidget {
    override func build(_ context: any BuildContext) -> Widget {
        return ScaffoldPage.scrollable(
            header: PageHeader(title: Text("MenuBar")),
            children: [
                SectionHeader("Menu Bar"),
                MenuBar_(
                    items: [
                        MenuBarItem(
                            text: Text("File"),
                            items: [
                                MenuFlyoutItem(text: Text("New"), onPressed: {}),
                                MenuFlyoutItem(text: Text("Open"), onPressed: {}),
                                MenuFlyoutItem(text: Text("Save"), onPressed: {}),
                                MenuFlyoutSeparator(),
                                MenuFlyoutItem(text: Text("Exit"), onPressed: {}),
                            ]
                        ),
                        MenuBarItem(
                            text: Text("Edit"),
                            items: [
                                MenuFlyoutItem(text: Text("Undo"), onPressed: {}),
                                MenuFlyoutItem(text: Text("Redo"), onPressed: {}),
                                MenuFlyoutSeparator(),
                                MenuFlyoutItem(text: Text("Cut"), onPressed: {}),
                                MenuFlyoutItem(text: Text("Copy"), onPressed: {}),
                                MenuFlyoutItem(text: Text("Paste"), onPressed: {}),
                            ]
                        ),
                        MenuBarItem(
                            text: Text("Help"),
                            items: [
                                MenuFlyoutItem(text: Text("About"), onPressed: {}),
                            ]
                        ),
                    ]
                ),
            ]
        )
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - Navigation Page
// ═══════════════════════════════════════════════════════════════════════════════

class NavigationDemoPage: StatefulWidget {
    override func createState() -> State<StatefulWidget> { _NavigationDemoPageState() }
}

class _NavigationDemoPageState: State<StatefulWidget> {
    var currentTab = 0

    override func build(_ context: any BuildContext) -> Widget {
        let theme = FluentTheme.of(context)
        return ScaffoldPage.scrollable(
            header: PageHeader(title: Text("Navigation")),
            children: [
                SectionHeader("TabView"),
                SizedBox(
                    height: 200,
                    child: TabView(
                        currentIndex: currentTab,
                        tabs: [
                            Tab(
                                text: Text("Documents"),
                                body: Center(child: Text("Documents content", style: theme.typography.body))
                            ),
                            Tab(
                                text: Text("Pictures"),
                                body: Center(child: Text("Pictures content", style: theme.typography.body))
                            ),
                            Tab(
                                text: Text("Music"),
                                body: Center(child: Text("Music content", style: theme.typography.body))
                            ),
                        ],
                        onChanged: { [self] idx in setState { currentTab = idx } }
                    )
                ),

                SectionHeader("TreeView"),
                SizedBox(
                    height: 200,
                    child: TreeView(
                        items: [
                            TreeViewItem(
                                content: Text("Documents"),
                                children: [
                                    TreeViewItem(content: Text("Work")),
                                    TreeViewItem(content: Text("Personal")),
                                    TreeViewItem(
                                        content: Text("Projects"),
                                        children: [
                                            TreeViewItem(content: Text("Flutter Swift")),
                                            TreeViewItem(content: Text("Fluent UI")),
                                        ]
                                    ),
                                ]
                            ),
                            TreeViewItem(
                                content: Text("Pictures"),
                                children: [
                                    TreeViewItem(content: Text("Vacation")),
                                    TreeViewItem(content: Text("Family")),
                                ]
                            ),
                            TreeViewItem(content: Text("Music")),
                        ],
                        selectionMode: .single
                    )
                ),

                SectionHeader("BreadcrumbBar"),
                BreadcrumbBar<String>(
                    items: [
                        BreadcrumbItem<String>(label: Text("Home"), value: "home"),
                        BreadcrumbItem<String>(label: Text("Documents"), value: "docs"),
                        BreadcrumbItem<String>(label: Text("Projects"), value: "projects"),
                    ]
                ),
            ]
        )
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - Pickers Page
// ═══════════════════════════════════════════════════════════════════════════════

class PickersPage: StatefulWidget {
    override func createState() -> State<StatefulWidget> { _PickersPageState() }
}

class _PickersPageState: State<StatefulWidget> {
    var selectedDate: FluentDateTime? = FluentDateTime.now()
    var selectedTime: FluentDateTime? = FluentDateTime.now()
    var pickerColor: Color = Color(0xFF0078D4)
    var calendarDate: FluentDateTime? = FluentDateTime.now()

    override func build(_ context: any BuildContext) -> Widget {
        return ScaffoldPage.scrollable(
            header: PageHeader(title: Text("Pickers")),
            children: [
                SectionHeader("Date Picker"),
                DatePicker(
                    selected: selectedDate,
                    onChanged: { [self] val in setState { selectedDate = val } },
                    header: "Select a date"
                ),

                SectionHeader("Time Picker"),
                TimePicker(
                    selected: selectedTime,
                    onChanged: { [self] val in setState { selectedTime = val } },
                    header: "Select a time",
                    hourFormat: .h12
                ),

                SectionHeader("Calendar Date Picker"),
                CalendarDatePicker(
                    selectedDate: calendarDate,
                    onDateChanged: { [self] val in setState { calendarDate = val } },
                    header: "Pick a date"
                ),

                SectionHeader("Color Picker"),
                SizedBox(
                    height: 320,
                    child: ColorPicker(
                        color: pickerColor,
                        onChanged: { [self] val in setState { pickerColor = val } },
                        isAlphaEnabled: false
                    )
                ),
            ]
        )
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - Main App (NavigationView shell)
// ═══════════════════════════════════════════════════════════════════════════════

class FluentDemoApp: StatefulWidget {
    override func createState() -> State<StatefulWidget> { _FluentDemoAppState() }
}

class _FluentDemoAppState: State<StatefulWidget> {
    var selectedIndex = 0

    override func build(_ context: any BuildContext) -> Widget {
        return FluentApp(
            theme: FluentThemeData(brightness: .light),
            themeMode: .light,
            home: NavigationView(
                pane: NavigationPane(
                    selected: selectedIndex,
                    onChanged: { [self] index in setState { selectedIndex = index } },
                    items: [
                        PaneItem(
                            icon: Text("\u{2302}"),
                            title: Text("Home"),
                            body: HomePage()
                        ),
                        PaneItemSeparator(),

                        PaneItemExpander(
                            icon: Text("\u{25A3}"),
                            title: Text("Basic Controls"),
                            body: ButtonsPage(),
                            items: [
                                PaneItem(
                                    icon: Text("\u{25A3}"),
                                    title: Text("Buttons"),
                                    body: ButtonsPage()
                                ),
                                PaneItem(
                                    icon: Text("\u{2611}"),
                                    title: Text("Inputs"),
                                    body: InputsPage()
                                ),
                                PaneItem(
                                    icon: Text("\u{270E}"),
                                    title: Text("Text & Form"),
                                    body: TextFormPage()
                                ),
                            ]
                        ),

                        PaneItemExpander(
                            icon: Text("\u{25A1}"),
                            title: Text("Surfaces"),
                            body: SurfacesPage(),
                            items: [
                                PaneItem(
                                    icon: Text("\u{25A1}"),
                                    title: Text("Surfaces"),
                                    body: SurfacesPage()
                                ),
                                PaneItem(
                                    icon: Text("\u{2261}"),
                                    title: Text("CommandBar"),
                                    body: CommandBarPage()
                                ),
                            ]
                        ),

                        PaneItemExpander(
                            icon: Text("\u{2630}"),
                            title: Text("Navigation"),
                            body: NavigationDemoPage(),
                            items: [
                                PaneItem(
                                    icon: Text("\u{2630}"),
                                    title: Text("Navigation"),
                                    body: NavigationDemoPage()
                                ),
                            ]
                        ),

                        PaneItemExpander(
                            icon: Text("\u{2B1A}"),
                            title: Text("Popups"),
                            body: DialogsPage(),
                            items: [
                                PaneItem(
                                    icon: Text("\u{2B1A}"),
                                    title: Text("Dialogs & Flyouts"),
                                    body: DialogsPage()
                                ),
                                PaneItem(
                                    icon: Text("\u{1F4AC}"),
                                    title: Text("TeachingTip"),
                                    body: TeachingTipPage()
                                ),
                                PaneItem(
                                    icon: Text("\u{2261}"),
                                    title: Text("MenuBar"),
                                    body: MenuBarPage()
                                ),
                            ]
                        ),

                        PaneItem(
                            icon: Text("\u{1F4C5}"),
                            title: Text("Pickers"),
                            body: PickersPage()
                        ),
                    ],
                    displayMode: .open
                )
            )
        )
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - Entry Point
// ═══════════════════════════════════════════════════════════════════════════════

#if os(macOS)

let app = NSApplication.shared
app.setActivationPolicy(.regular)

let engine = FlutterEngine(name: "swift-app", project: nil, allowHeadlessExecution: true)

runApp(FluentDemoApp())

var callbacks = createRuntimeCallbacks()
let started = withUnsafePointer(to: &callbacks) { ptr in
    engine.runSwift(withRuntimeCallbacks: UnsafeRawPointer(ptr))
}
guard started else {
    fatalError("[FluentDemoApp] Failed to start engine in Swift mode")
}

let viewController = FlutterViewController(engine: engine, nibName: nil, bundle: nil)

let window = NSWindow(
    contentRect: NSMakeRect(0, 0, 1100, 700),
    styleMask: [.titled, .closable, .miniaturizable, .resizable],
    backing: .buffered,
    defer: false
)
window.title = "Fluent UI for Swift — Demo"
window.contentViewController = viewController
window.setContentSize(NSMakeSize(1100, 700))
window.center()
window.makeKeyAndOrderFront(nil)
app.activate(ignoringOtherApps: true)

PlatformDispatcher.instance.scheduleFrame()
app.run()

#elseif os(Linux)

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - Linux: Windowed entry point using Flutter embedder API + GLFW3
// ═══════════════════════════════════════════════════════════════════════════════
//
// Creates an X11 window via GLFW3, renders with OpenGL ES 2 via EGL, and
// forwards mouse/keyboard input to the Flutter engine. Falls back to the
// headless software renderer when --headless is passed.

// ─── AppState ────────────────────────────────────────────────────────────────

/// Holds all mutable state shared between GLFW callbacks and the embedder.
/// Passed as `Unmanaged<AppState>.toOpaque()` through the embedder's
/// `user_data` and GLFW's `glfwSetWindowUserPointer`.
///
/// Must NOT be @MainActor — engine callbacks come from io/raster threads.
/// @unchecked Sendable because we manually synchronize access (main thread
/// for GLFW callbacks, NSLock for taskQueue).
final class AppState: @unchecked Sendable {
    nonisolated(unsafe) var window: OpaquePointer? = nil
    nonisolated(unsafe) var resourceWindow: OpaquePointer? = nil
    nonisolated(unsafe) var engine: OpaquePointer? = nil

    nonisolated(unsafe) var pixelsPerScreenCoord: Double = 1.0

    // Pointer state machine (mirrors flutter_glfw.cc)
    nonisolated(unsafe) var pointerAdded = false
    nonisolated(unsafe) var pointerDown = false
    nonisolated(unsafe) var buttons: Int64 = 0

    nonisolated let taskQueue = FlutterTaskQueue()
    nonisolated let mainThreadPthread = pthread_self()
}

// ─── FlutterTaskQueue ────────────────────────────────────────────────────────

/// Thread-safe priority queue of engine tasks. The engine posts tasks from
/// arbitrary threads; we drain them on the main GLFW thread.
class FlutterTaskQueue: @unchecked Sendable {
    private let lock = NSLock()
    private var tasks: [(task: FlutterTask, targetNanos: UInt64)] = []

    func enqueue(_ task: FlutterTask, targetNanos: UInt64) {
        lock.lock()
        tasks.append((task, targetNanos))
        lock.unlock()
        // Wake the GLFW event loop so it can drain this task
        glfwPostEmptyEvent()
    }

    /// Returns (expired tasks, next-deadline-nanos-or-nil).
    func drainExpired() -> (expired: [(FlutterTask, UInt64)], nextNanos: UInt64?) {
        let now = FlutterEngineGetCurrentTime()
        lock.lock()
        var expired: [(FlutterTask, UInt64)] = []
        var remaining: [(task: FlutterTask, targetNanos: UInt64)] = []
        for entry in tasks {
            if entry.targetNanos <= now {
                expired.append((entry.task, entry.targetNanos))
            } else {
                remaining.append(entry)
            }
        }
        tasks = remaining
        let nextNanos = remaining.map(\.targetNanos).min()
        lock.unlock()
        return (expired, nextNanos)
    }
}

// ─── Pointer helpers ─────────────────────────────────────────────────────────

/// Sends a pointer event to the Flutter engine, handling the add/remove
/// synthesis protocol that the engine requires.
func sendPointerEvent(
    _ state: AppState,
    phase: FlutterPointerPhase,
    x: Double,
    y: Double,
    signalKind: FlutterPointerSignalKind = kFlutterPointerSignalKindNone,
    scrollDeltaX: Double = 0,
    scrollDeltaY: Double = 0,
    buttons: Int64 = 0
) {
    guard let engine = state.engine else { return }

    // Synthesise kAdd if the pointer hasn't been added yet
    if !state.pointerAdded && phase != kAdd {
        sendPointerEvent(state, phase: kAdd, x: x, y: y)
    }
    // Don't double-add
    if state.pointerAdded && phase == kAdd { return }

    var event = FlutterPointerEvent()
    event.struct_size = MemoryLayout<FlutterPointerEvent>.size
    event.phase = phase
    event.timestamp = Int(FlutterEngineGetCurrentTime() / 1000)  // ns → µs
    event.x = x * state.pixelsPerScreenCoord
    event.y = y * state.pixelsPerScreenCoord
    event.device = 0
    event.signal_kind = signalKind
    event.scroll_delta_x = scrollDeltaX
    event.scroll_delta_y = scrollDeltaY
    event.device_kind = kFlutterPointerDeviceKindMouse
    event.buttons = buttons
    event.view_id = 0

    FlutterEngineSendPointerEvent(engine, &event, 1)

    // Update state machine
    switch phase {
    case kAdd:    state.pointerAdded = true
    case kRemove: state.pointerAdded = false
    case kDown:   state.pointerDown = true
    case kUp:     state.pointerDown = false
    default: break
    }
}

/// Determines the correct pointer phase based on current button state,
/// matching the flutter_glfw.cc state machine.
func pointerPhaseForButtonState(_ state: AppState) -> FlutterPointerPhase {
    if state.buttons == 0 {
        return state.pointerDown ? kUp : kHover
    } else {
        return state.pointerDown ? kMove : kDown
    }
}

// ─── GLFW callbacks (non-capturing closures → C function pointers) ───────────

/// Retrieves AppState from GLFW's per-window user pointer.
func getAppState(_ window: OpaquePointer?) -> AppState? {
    guard let window = window,
          let ptr = glfwGetWindowUserPointer(window) else { return nil }
    return Unmanaged<AppState>.fromOpaque(ptr).takeUnretainedValue()
}

// Framebuffer resize → send window metrics
let glfwFramebufferSizeCallback: @convention(c) (
    OpaquePointer?, Int32, Int32
) -> Void = { window, widthPx, heightPx in
    guard let state = getAppState(window), let engine = state.engine else { return }
    var widthScreen: Int32 = 0
    glfwGetWindowSize(window, &widthScreen, nil)
    state.pixelsPerScreenCoord = widthScreen > 0
        ? Double(widthPx) / Double(widthScreen) : 1.0

    var metrics = FlutterWindowMetricsEvent()
    metrics.struct_size = MemoryLayout<FlutterWindowMetricsEvent>.size
    metrics.width = Int(widthPx)
    metrics.height = Int(heightPx)
    metrics.pixel_ratio = state.pixelsPerScreenCoord
    metrics.view_id = 0
    FlutterEngineSendWindowMetricsEvent(engine, &metrics)
}

// Cursor position → hover or move
let glfwCursorPosCallback: @convention(c) (
    OpaquePointer?, Double, Double
) -> Void = { window, x, y in
    guard let state = getAppState(window) else { return }
    let phase = pointerPhaseForButtonState(state)
    sendPointerEvent(state, phase: phase, x: x, y: y, buttons: state.buttons)
}

// Cursor enter/leave → add/remove
let glfwCursorEnterCallback: @convention(c) (
    OpaquePointer?, Int32
) -> Void = { window, entered in
    guard let state = getAppState(window) else { return }
    var x: Double = 0, y: Double = 0
    glfwGetCursorPos(window, &x, &y)
    if entered != 0 {
        sendPointerEvent(state, phase: kAdd, x: x, y: y)
    } else {
        sendPointerEvent(state, phase: kRemove, x: x, y: y)
    }
}

// Mouse button → down/up with button tracking
let glfwMouseButtonCallback: @convention(c) (
    OpaquePointer?, Int32, Int32, Int32
) -> Void = { window, key, action, _ in
    guard let state = getAppState(window) else { return }
    let flutterButton: Int64
    switch key {
    case GLFW_MOUSE_BUTTON_LEFT:   flutterButton = Int64(kFlutterPointerButtonMousePrimary.rawValue)
    case GLFW_MOUSE_BUTTON_RIGHT:  flutterButton = Int64(kFlutterPointerButtonMouseSecondary.rawValue)
    case GLFW_MOUSE_BUTTON_MIDDLE: flutterButton = Int64(kFlutterPointerButtonMouseMiddle.rawValue)
    default: return
    }
    if action == GLFW_PRESS {
        state.buttons |= flutterButton
    } else {
        state.buttons &= ~flutterButton
    }
    let phase = pointerPhaseForButtonState(state)
    var x: Double = 0, y: Double = 0
    glfwGetCursorPos(window, &x, &y)
    sendPointerEvent(state, phase: phase, x: x, y: y, buttons: state.buttons)
}

// Scroll → kScroll signal with 20px multiplier (matches flutter_glfw.cc)
let glfwScrollCallback: @convention(c) (
    OpaquePointer?, Double, Double
) -> Void = { window, deltaX, deltaY in
    guard let state = getAppState(window) else { return }
    let phase = pointerPhaseForButtonState(state)
    var x: Double = 0, y: Double = 0
    glfwGetCursorPos(window, &x, &y)
    let kScrollMultiplier = 20.0
    sendPointerEvent(
        state, phase: phase, x: x, y: y,
        signalKind: kFlutterPointerSignalKindScroll,
        scrollDeltaX: deltaX * kScrollMultiplier,
        scrollDeltaY: -deltaY * kScrollMultiplier,
        buttons: state.buttons
    )
}

// Keyboard → FlutterEngineSendKeyEvent with minimal GLFW→HID mapping
let glfwKeyCallback: @convention(c) (
    OpaquePointer?, Int32, Int32, Int32, Int32
) -> Void = { window, key, _scancode, action, _mods in
    guard let state = getAppState(window), let engine = state.engine else { return }
    guard action == GLFW_PRESS || action == GLFW_RELEASE || action == GLFW_REPEAT else { return }

    let eventType: FlutterKeyEventType
    switch action {
    case GLFW_PRESS:  eventType = kFlutterKeyEventTypeDown
    case GLFW_REPEAT: eventType = kFlutterKeyEventTypeRepeat
    default:          eventType = kFlutterKeyEventTypeUp
    }

    // Minimal GLFW key → USB HID physical key mapping
    let physical: UInt64 = glfwKeyToHID(Int(key))
    // For logical keys, use the same value (simplified mapping)
    let logical: UInt64 = physical

    var event = FlutterKeyEvent()
    event.struct_size = MemoryLayout<FlutterKeyEvent>.size
    event.timestamp = Double(FlutterEngineGetCurrentTime()) / 1000.0
    event.type = eventType
    event.physical = physical
    event.logical = logical
    event.character = nil
    event.synthesized = false
    event.device_type = kFlutterKeyEventDeviceTypeKeyboard
    FlutterEngineSendKeyEvent(engine, &event, nil, nil)
}

/// Minimal GLFW key code → USB HID usage page 0x07 physical key mapping.
/// Covers A-Z, 0-9, arrows, modifiers, and common keys.
func glfwKeyToHID(_ key: Int) -> UInt64 {
    switch key {
    // Letters A-Z: GLFW uses ASCII 65-90, HID uses 0x04-0x1D
    case 65...90: return UInt64(key - 65 + 0x04)
    // Digits 0-9: GLFW uses ASCII 48-57, HID 0x27 for 0, 0x1E-0x26 for 1-9
    case 48: return 0x27
    case 49...57: return UInt64(key - 49 + 0x1E)
    // Arrow keys
    case 262: return 0x4F  // Right
    case 263: return 0x50  // Left
    case 264: return 0x51  // Down
    case 265: return 0x52  // Up
    // Common keys
    case 256: return 0x29  // Escape
    case 257: return 0x28  // Enter
    case 258: return 0x2B  // Tab
    case 259: return 0x2A  // Backspace
    case 32:  return 0x2C  // Space
    // Modifiers
    case 340: return 0xE1  // Left Shift
    case 341: return 0xE0  // Left Control
    case 342: return 0xE2  // Left Alt
    case 344: return 0xE5  // Right Shift
    case 345: return 0xE4  // Right Control
    case 346: return 0xE6  // Right Alt
    default:  return UInt64(key) | 0x00100000000  // unmapped, use raw + flag
    }
}

// ─── DRM/KMS mode (--drm flag) ───────────────────────────────────────────────

func runDRM() -> Never {
    print("[BlueScreenApp] Starting on Linux (DRM/KMS direct rendering)")

    // Build the widget tree and runtime callbacks.
    runApp(FluentDemoApp())
    var callbacks = createRuntimeCallbacks()

    let engineOutDir = "../../engine/src/out/host_debug"
    let assetsPath = "\(engineOutDir)/flutter_assets"
    let icuPath = "\(engineOutDir)/icudtl.dat"

    // Create the DRM view — this initializes DRM display, GBM, EGL,
    // the Flutter engine, and input handling.
    guard let view = withUnsafeMutablePointer(to: &callbacks, { cbPtr in
        fl_drm_view_create(assetsPath, icuPath, UnsafeMutableRawPointer(cbPtr))
    }) else {
        fatalError("[BlueScreenApp] fl_drm_view_create failed")
    }

    print("[BlueScreenApp] DRM view created: \(fl_drm_view_get_width(view))x\(fl_drm_view_get_height(view))")

    // Schedule first frame.
    PlatformDispatcher.instance.scheduleFrame()

    // Run the event loop (blocks until shutdown).
    fl_drm_view_run(view)

    // Cleanup.
    fl_drm_view_destroy(view)
    print("[BlueScreenApp] DRM shutdown complete")
    exit(0)
}

// ─── Headless fallback (--headless flag) ─────────────────────────────────────

func runHeadless() -> Never {
    print("[BlueScreenApp] Starting on Linux (headless, software renderer)")

    runApp(FluentDemoApp())
    var callbacks = createRuntimeCallbacks()

    var rendererConfig = FlutterRendererConfig()
    rendererConfig.type = kSoftware
    rendererConfig.software.struct_size = MemoryLayout<FlutterSoftwareRendererConfig>.size
    rendererConfig.software.surface_present_callback = {
        (_userData, _allocation, rowBytes, height) -> Bool in
        print("[BlueScreenApp] Software surface presented: \(rowBytes)x\(height)")
        return true
    }

    var args = FlutterProjectArgs()
    args.struct_size = MemoryLayout<FlutterProjectArgs>.size
    let engineOutDir = "../../engine/src/out/host_debug"
    let assetsPath = strdup("\(engineOutDir)/flutter_assets")!
    let icuPath = strdup("\(engineOutDir)/icudtl.dat")!
    args.assets_path = UnsafePointer(assetsPath)
    args.icu_data_path = UnsafePointer(icuPath)

    let argv0 = strdup("BlueScreenApp")!
    let argv1 = strdup("--enable-impeller=false")!
    let argvBuf = UnsafeMutableBufferPointer<UnsafePointer<CChar>?>.allocate(capacity: 3)
    argvBuf[0] = UnsafePointer(argv0)
    argvBuf[1] = UnsafePointer(argv1)
    argvBuf[2] = nil
    args.command_line_argc = 2
    args.command_line_argv = UnsafePointer(argvBuf.baseAddress!)

    var engine: OpaquePointer? = nil
    let initResult = withUnsafeMutablePointer(to: &callbacks) { cbPtr in
        FlutterEngineInitializeSwift(
            Int(FLUTTER_ENGINE_VERSION),
            &rendererConfig,
            &args,
            nil,
            UnsafeRawPointer(cbPtr),
            &engine
        )
    }
    guard initResult == kSuccess, let engine = engine else {
        fatalError("[BlueScreenApp] FlutterEngineInitializeSwift failed")
    }
    let runResult = FlutterEngineRunInitializedSwift(engine)
    guard runResult == kSuccess else {
        fatalError("[BlueScreenApp] FlutterEngineRunInitializedSwift failed")
    }
    var metrics = FlutterWindowMetricsEvent()
    metrics.struct_size = MemoryLayout<FlutterWindowMetricsEvent>.size
    metrics.width = 1100; metrics.height = 700
    metrics.pixel_ratio = 1.0; metrics.view_id = 0
    FlutterEngineSendWindowMetricsEvent(engine, &metrics)
    PlatformDispatcher.instance.scheduleFrame()
    print("[BlueScreenApp] Headless engine running, entering run loop")
    Foundation.RunLoop.main.run()
    exit(0)
}

// ─── Windowed entry point ────────────────────────────────────────────────────

// Check for --drm flag (DRM/KMS direct rendering)
if CommandLine.arguments.contains("--drm") {
    runDRM()
}

// Check for --headless flag
if CommandLine.arguments.contains("--headless") {
    runHeadless()
}

print("[BlueScreenApp] Starting on Linux (GLFW3 + OpenGL)")

// 1. Initialize GLFW
guard glfwInit() != 0 else {
    fatalError("[BlueScreenApp] glfwInit() failed")
}

// Request OpenGL ES 2.0 via EGL.
// If EGL context creation fails, fall back to native desktop OpenGL.
glfwWindowHint(GLFW_CLIENT_API, GLFW_OPENGL_ES_API)
glfwWindowHint(GLFW_CONTEXT_CREATION_API, GLFW_EGL_CONTEXT_API)
glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 2)
glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 0)

// 2. Create main window
guard let mainWindow = glfwCreateWindow(1100, 700, "Fluent UI for Swift — Demo", nil, nil) else {
    glfwTerminate()
    fatalError("[BlueScreenApp] glfwCreateWindow() failed")
}

// 3. Create invisible resource window (shares GL context with main)
glfwWindowHint(GLFW_VISIBLE, 0)  // GLFW_FALSE
let resourceWindow = glfwCreateWindow(1, 1, "", nil, mainWindow)
glfwWindowHint(GLFW_VISIBLE, 1)  // Reset for future windows

// 4. Set up AppState
let appState = AppState()
appState.window = mainWindow
appState.resourceWindow = resourceWindow

let statePtr = Unmanaged.passRetained(appState).toOpaque()
glfwSetWindowUserPointer(mainWindow, statePtr)

// 5. Set up the Swift widget tree + runtime callbacks
runApp(FluentDemoApp())
var callbacks = createRuntimeCallbacks()

// 6. Configure OpenGL renderer
var rendererConfig = FlutterRendererConfig()
rendererConfig.type = kOpenGL
rendererConfig.open_gl.struct_size = MemoryLayout<FlutterOpenGLRendererConfig>.size

rendererConfig.open_gl.make_current = { userData -> Bool in
    guard let userData = userData else { return false }
    let state = Unmanaged<AppState>.fromOpaque(userData).takeUnretainedValue()
    glfwMakeContextCurrent(state.window)
    return true
}

rendererConfig.open_gl.clear_current = { _ -> Bool in
    glfwMakeContextCurrent(nil)
    return true
}

rendererConfig.open_gl.present = { userData -> Bool in
    guard let userData = userData else { return false }
    let state = Unmanaged<AppState>.fromOpaque(userData).takeUnretainedValue()
    glfwSwapBuffers(state.window)
    return true
}

rendererConfig.open_gl.fbo_callback = { _ -> UInt32 in
    return 0  // on-screen framebuffer
}

rendererConfig.open_gl.make_resource_current = { userData -> Bool in
    guard let userData = userData else { return false }
    let state = Unmanaged<AppState>.fromOpaque(userData).takeUnretainedValue()
    glfwMakeContextCurrent(state.resourceWindow)
    return true
}

rendererConfig.open_gl.gl_proc_resolver = { _, name -> UnsafeMutableRawPointer? in
    guard let name = name else { return nil }
    guard let fn = glfwGetProcAddress(name) else { return nil }
    return unsafeBitCast(fn, to: UnsafeMutableRawPointer.self)
}

// 7. Configure custom task runner (platform thread)
var platformTaskRunner = FlutterTaskRunnerDescription()
platformTaskRunner.struct_size = MemoryLayout<FlutterTaskRunnerDescription>.size
platformTaskRunner.user_data = statePtr
platformTaskRunner.runs_task_on_current_thread_callback = { userData -> Bool in
    guard let userData = userData else { return false }
    let state = Unmanaged<AppState>.fromOpaque(userData).takeUnretainedValue()
    return pthread_equal(pthread_self(), state.mainThreadPthread) != 0
}
platformTaskRunner.post_task_callback = { task, targetTimeNanos, userData in
    guard let userData = userData else { return }
    let state = Unmanaged<AppState>.fromOpaque(userData).takeUnretainedValue()
    state.taskQueue.enqueue(task, targetNanos: targetTimeNanos)
}

var taskRunners = FlutterCustomTaskRunners()
taskRunners.struct_size = MemoryLayout<FlutterCustomTaskRunners>.size

// 8. Configure project args
var args = FlutterProjectArgs()
args.struct_size = MemoryLayout<FlutterProjectArgs>.size
let engineOutDir = "../../engine/src/out/host_debug"
let assetsPath = strdup("\(engineOutDir)/flutter_assets")!
let icuPath = strdup("\(engineOutDir)/icudtl.dat")!
args.assets_path = UnsafePointer(assetsPath)
args.icu_data_path = UnsafePointer(icuPath)

// Use Skia OpenGL backend (Impeller disabled for broader GPU compat)
let argv0 = strdup("BlueScreenApp")!
let argv1 = strdup("--enable-impeller=false")!
let argvBuf = UnsafeMutableBufferPointer<UnsafePointer<CChar>?>.allocate(capacity: 3)
argvBuf[0] = UnsafePointer(argv0)
argvBuf[1] = UnsafePointer(argv1)
argvBuf[2] = nil
args.command_line_argc = 2
args.command_line_argv = UnsafePointer(argvBuf.baseAddress!)

// Wire up custom task runners — must use withUnsafe to get stable pointers
// for the duration of engine init
var engine: OpaquePointer? = nil
let initResult = withUnsafeMutablePointer(to: &callbacks) { cbPtr in
    withUnsafeMutablePointer(to: &platformTaskRunner) { taskRunnerPtr in
        taskRunners.platform_task_runner = UnsafePointer(taskRunnerPtr)
        return withUnsafeMutablePointer(to: &taskRunners) { taskRunnersPtr in
            args.custom_task_runners = UnsafePointer(taskRunnersPtr)
            return FlutterEngineInitializeSwift(
                Int(FLUTTER_ENGINE_VERSION),
                &rendererConfig,
                &args,
                statePtr,  // user_data → passed to renderer callbacks
                UnsafeRawPointer(cbPtr),
                &engine
            )
        }
    }
}
guard initResult == kSuccess, let engine = engine else {
    glfwTerminate()
    fatalError("[BlueScreenApp] FlutterEngineInitializeSwift failed")
}
appState.engine = engine
print("[BlueScreenApp] Engine initialized (OpenGL)")

// 9. Run the engine
let runResult = FlutterEngineRunInitializedSwift(engine)
guard runResult == kSuccess else {
    glfwTerminate()
    fatalError("[BlueScreenApp] FlutterEngineRunInitializedSwift failed")
}
print("[BlueScreenApp] Engine running")

// 10. Register GLFW callbacks
glfwSetFramebufferSizeCallback(mainWindow, glfwFramebufferSizeCallback)
glfwSetCursorPosCallback(mainWindow, glfwCursorPosCallback)
glfwSetCursorEnterCallback(mainWindow, glfwCursorEnterCallback)
glfwSetMouseButtonCallback(mainWindow, glfwMouseButtonCallback)
glfwSetScrollCallback(mainWindow, glfwScrollCallback)
glfwSetKeyCallback(mainWindow, glfwKeyCallback)

// 11. Send initial window metrics
var widthPx: Int32 = 0, heightPx: Int32 = 0
glfwGetFramebufferSize(mainWindow, &widthPx, &heightPx)
glfwFramebufferSizeCallback(mainWindow, widthPx, heightPx)

// 12. Schedule first frame
PlatformDispatcher.instance.scheduleFrame()
print("[BlueScreenApp] First frame scheduled, entering GLFW event loop")

// 13. Event loop — replaces Foundation.RunLoop.main.run()
//     Must also spin the Foundation RunLoop so framework timers fire.
while glfwWindowShouldClose(mainWindow) == 0 {
    // Drain expired engine tasks
    let (expired, nextNanos) = appState.taskQueue.drainExpired()
    for (task, _) in expired {
        var mutableTask = task
        FlutterEngineRunTask(engine, &mutableTask)
    }

    // Spin Foundation RunLoop briefly for framework timers / schedulers
    Foundation.RunLoop.main.run(
        mode: .default,
        before: Date(timeIntervalSinceNow: 0.001)
    )

    // Compute wait duration from next engine task
    if let nextNanos = nextNanos {
        let now = FlutterEngineGetCurrentTime()
        if nextNanos > now {
            let waitSeconds = min(Double(nextNanos - now) / 1_000_000_000.0, 0.016)
            glfwWaitEventsTimeout(waitSeconds)
        } else {
            glfwPollEvents()
        }
    } else {
        // No pending engine tasks — still poll briefly for GLFW events
        // (don't block indefinitely since RunLoop timers may fire)
        glfwWaitEventsTimeout(0.016)  // ~60 Hz
    }
}

// Cleanup
FlutterEngineShutdown(engine)
glfwDestroyWindow(mainWindow)
if let rw = resourceWindow { glfwDestroyWindow(rw) }
glfwTerminate()
Unmanaged<AppState>.fromOpaque(statePtr).release()
print("[BlueScreenApp] Shutdown complete")

#endif
