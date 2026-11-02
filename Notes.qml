import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: root

    PersistentProperties {
        id: notePreferences
        reloadableId: "note-widget-position"
        property string anchorCorner: "top-right"
        property int offsetX: 0
        property int offsetY: 176
    }

    anchors {
        top: root.anchorCorner.startsWith("top-")
        bottom: root.anchorCorner.startsWith("bottom-")
        left: root.anchorCorner.endsWith("-left")
        right: root.anchorCorner.endsWith("-right")
    }
    margins {
        top: root.anchorCorner.startsWith("top-") ? root.offsetY : 0
        bottom: root.anchorCorner.startsWith("bottom-") ? root.offsetY : 0
        left: root.anchorCorner.endsWith("-left") ? root.offsetX : 0
        right: root.anchorCorner.endsWith("-right") ? root.offsetX : 0
    }
    implicitWidth: settingsOpen ? 220 : (isLarge ? 300 : 112)
    implicitHeight: settingsOpen ? 230 : (isLarge ? 390 : 72)
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.layer: (isLarge || settingsOpen) && activeWidget === "notes" ? WlrLayer.Overlay : WlrLayer.Bottom
    aboveWindows: (isLarge || settingsOpen) && activeWidget === "notes"
    WlrLayershell.keyboardFocus: isLarge || settingsOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    readonly property color bgColor: "#0c2028"
    readonly property color panelColor: "#163945"
    readonly property color borderColor: "#28515d"
    readonly property color accent: "#65d9df"
    readonly property color textColor: "#e7fcff"
    readonly property color dimColor: "#90b7bf"

    property var pages: [""]
    property var schedules: [{}]
    property int cur: 0
    property bool loading: false
    property bool isLarge: false
    property bool settingsOpen: false
    property bool scheduleOpen: false
    property string activeWidget: "none"
    property var sharedEvents: ({})
    property var sharedEventTimes: ({})
    property int selectedMonth: new Date().getMonth()
    property int selectedDay: new Date().getDate()
    property int selectedYear: new Date().getFullYear()
    property int selectedHour: (new Date().getHours() + 1) % 24
    property int selectedMinute: 0
    property string anchorCorner: notePreferences.anchorCorner
    property int offsetX: notePreferences.offsetX
    property int offsetY: notePreferences.offsetY
    property string icsPath: ""
    property string statusText: "Set a date and time to schedule this note"
    property real framePulse: 0.35
    readonly property string dir: Quickshell.env("HOME") + "/.local/share/qs-notes"
    readonly property string focusPath: Quickshell.env("XDG_RUNTIME_DIR") + "/daymark-widget-focus"
    readonly property string sharedEventsPath: dir + "/calendar-events.json"
    readonly property var monthOptions: ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
    readonly property var yearOptions: {
        var values = []
        var currentYear = new Date().getFullYear()
        for (var year = currentYear - 5; year <= currentYear + 10; year++) values.push(year)
        return values
    }
    readonly property var hourOptions: ["01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12"]
    readonly property var minuteOptions: {
        var values = []
        for (var minute = 0; minute < 60; minute++) values.push(minute < 10 ? "0" + minute : String(minute))
        return values
    }
    readonly property var dayOptions: {
        var values = []
        var count = new Date(selectedYear, selectedMonth + 1, 0).getDate()
        for (var day = 1; day <= count; day++) values.push(day)
        return values
    }

    SequentialAnimation on framePulse {
        loops: Animation.Infinite
        NumberAnimation { from: 0.3; to: 0.9; duration: 1500; easing.type: Easing.InOutSine }
        NumberAnimation { from: 0.9; to: 0.3; duration: 1500; easing.type: Easing.InOutSine }
    }

    onAnchorCornerChanged: notePreferences.anchorCorner = anchorCorner
    onOffsetXChanged: notePreferences.offsetX = offsetX
    onOffsetYChanged: notePreferences.offsetY = offsetY
    onIsLargeChanged: syncWidgetFocus()
    onSettingsOpenChanged: syncWidgetFocus()
    onActiveWidgetChanged: {
        if (activeWidget === "none" && (isLarge || settingsOpen)) syncWidgetFocus()
        else if (activeWidget === "notes" && !isLarge && !settingsOpen) syncWidgetFocus()
    }

    Component.onCompleted: {
        if (anchorCorner === "top-right" && offsetX === 16 && offsetY === 160) {
            offsetX = 0
            offsetY = 176
        }
    }

    function syncWidgetFocus() {
        if (isLarge || settingsOpen) {
            focusFile.setText("notes")
            activeWidget = "notes"
        } else if (activeWidget === "notes") {
            focusFile.setText("none")
            activeWidget = "none"
        }
    }

    function save() { saveTimer.restart() }

    function go(i) {
        if (i < 0 || i >= pages.length) return
        cur = i
        loading = true
        editor.text = pages[cur]
        var schedule = schedules[cur] || {}
        titleField.text = schedule.title || ""
        loadSchedule(schedule)
        scheduleOpen = false
        statusText = "Set a date and time to schedule this note"
        loading = false
        save()
    }

    function loadSchedule(schedule) {
        var dateMatch = String(schedule.date || "").match(/^(\d{4})[-/](\d{1,2})[-/](\d{1,2})$/)
        var now = new Date()
        if (dateMatch) {
            var year = Number(dateMatch[1])
            var month = Number(dateMatch[2]) - 1
            var day = Number(dateMatch[3])
            var parsedDate = new Date(year, month, day)
            if (parsedDate.getFullYear() === year && parsedDate.getMonth() === month && parsedDate.getDate() === day) {
                selectedYear = year
                selectedMonth = month
                selectedDay = day
            } else {
                selectedYear = now.getFullYear()
                selectedMonth = now.getMonth()
                selectedDay = now.getDate()
            }
        } else {
            selectedYear = now.getFullYear()
            selectedMonth = now.getMonth()
            selectedDay = now.getDate()
        }

        var timeMatch = String(schedule.time || "").match(/^(\d{1,2}):(\d{1,2})$/)
        selectedHour = timeMatch ? Math.min(23, Number(timeMatch[1])) : (now.getHours() + 1) % 24
        selectedMinute = timeMatch ? Math.min(59, Number(timeMatch[2])) : 0
        selectedDay = Math.min(selectedDay, new Date(selectedYear, selectedMonth + 1, 0).getDate())
    }

    function dateKey() {
        function two(value) { return value < 10 ? "0" + value : String(value) }
        return selectedYear + "-" + two(selectedMonth + 1) + "-" + two(selectedDay)
    }

    function timeKey() {
        function two(value) { return value < 10 ? "0" + value : String(value) }
        return two(selectedHour) + ":" + two(selectedMinute)
    }

    function normalizeDate(value) {
        var parts = String(value || "").match(/^(\d{4})[-/](\d{1,2})[-/](\d{1,2})$/)
        if (!parts) return ""
        var year = Number(parts[1])
        var month = Number(parts[2])
        var day = Number(parts[3])
        var parsed = new Date(year, month - 1, day)
        if (parsed.getFullYear() !== year || parsed.getMonth() !== month - 1 || parsed.getDate() !== day) return ""
        return year + "-" + (month < 10 ? "0" : "") + month + "-" + (day < 10 ? "0" : "") + day
    }

    function normalizeTime(value) {
        var parts = String(value || "").match(/^(\d{1,2}):(\d{1,2})$/)
        if (!parts) return ""
        var hour = Number(parts[1])
        var minute = Number(parts[2])
        if (hour > 23 || minute > 59) return ""
        return (hour < 10 ? "0" : "") + hour + ":" + (minute < 10 ? "0" : "") + minute
    }

    function removeCalendarEvent(schedule, noteText) {
        var linkedEvent = schedule.calendarEvent || null
        var key = linkedEvent ? linkedEvent.date : normalizeDate(schedule.date)
        var title = linkedEvent ? linkedEvent.title
                                : (schedule.title || String(noteText || "").trim().split("\n")[0] || "Note reminder")
        var time = linkedEvent ? linkedEvent.time : normalizeTime(schedule.time)

        if (!key || sharedEvents[key] !== title) return false
        if (time && sharedEventTimes[key] && sharedEventTimes[key] !== time) return false

        var events = Object.assign({}, sharedEvents)
        var times = Object.assign({}, sharedEventTimes)
        delete events[key]
        delete times[key]
        sharedEvents = events
        sharedEventTimes = times
        sharedEventsFile.setText(JSON.stringify({ events: events, eventTimes: times }))
        return true
    }

    function scheduleSummary() {
        var linkedEvent = (schedules[cur] || {}).calendarEvent
        if (!linkedEvent) return "OPTIONAL"
        return Qt.formatDate(new Date(linkedEvent.date + "T00:00:00"), "MMM d") + " " + linkedEvent.time
    }

    function updateSchedule() {
        if (loading) return
        var updated = schedules.slice()
        while (updated.length <= cur) updated.push({})
        var current = updated[cur] || {}
        updated[cur] = {
            title: titleField.text,
            date: dateKey(),
            time: timeKey(),
            calendarEvent: current.calendarEvent || null
        }
        schedules = updated
        save()
    }

    function escapeIcs(value) {
        return String(value).replace(/\\/g, "\\\\").replace(/\r?\n/g, "\\n").replace(/,/g, "\\,").replace(/;/g, "\\;")
    }

    function localStamp(date) {
        function two(number) { return number < 10 ? "0" + number : String(number) }
        return date.getFullYear() + two(date.getMonth() + 1) + two(date.getDate()) + "T" + two(date.getHours()) + two(date.getMinutes()) + "00"
    }

    function createCalendarEvent() {
        var start = new Date(selectedYear, selectedMonth, selectedDay, selectedHour, selectedMinute)
        if (start.getFullYear() !== selectedYear || start.getMonth() !== selectedMonth || start.getDate() !== selectedDay) {
            statusText = "Enter a valid date and time"
            return
        }

        var end = new Date(start.getTime() + 60 * 60 * 1000)
        var title = titleField.text.trim() || editor.text.trim().split("\n")[0] || "Note reminder"
        var description = editor.text.trim()
        updateSchedule()
        removeCalendarEvent(schedules[cur] || {}, pages[cur] || "")
        var key = dateKey()
        var events = Object.assign({}, sharedEvents)
        var times = Object.assign({}, sharedEventTimes)
        events[key] = title
        times[key] = timeKey()
        sharedEvents = events
        sharedEventTimes = times
        sharedEventsFile.setText(JSON.stringify({ events: events, eventTimes: times }))

        var updatedSchedules = schedules.slice()
        var currentSchedule = Object.assign({}, updatedSchedules[cur] || {})
        currentSchedule.calendarEvent = { date: key, time: timeKey(), title: title }
        updatedSchedules[cur] = currentSchedule
        schedules = updatedSchedules
        save()

        var stamp = new Date().toISOString().replace(/[-:]/g, "").replace(/\.\d{3}/, "")
        var content = [
            "BEGIN:VCALENDAR", "VERSION:2.0", "PRODID:-//QS Notes//Calendar Event//EN",
            "BEGIN:VEVENT", "UID:" + Date.now() + "@qs-notes", "DTSTAMP:" + stamp,
            "DTSTART:" + localStamp(start), "DTEND:" + localStamp(end),
            "SUMMARY:" + escapeIcs(title), "DESCRIPTION:" + escapeIcs(description),
            "END:VEVENT", "END:VCALENDAR", ""
        ].join("\r\n")

        icsPath = dir + "/calendar-event-" + Date.now() + ".ics"
        eventFile.path = icsPath
        eventFile.setText(content)
        statusText = "Added to calendar. Opening event..."
        openTimer.start()
    }

    function addPage() {
        var p = pages.slice()
        p.push("")
        pages = p
        var s = schedules.slice()
        s.push({})
        schedules = s
        go(pages.length - 1)
        editor.forceActiveFocus()
    }

    function deletePage() {
        removeCalendarEvent(schedules[cur] || {}, pages[cur] || "")
        var p = pages.slice()
        p.splice(cur, 1)
        if (p.length === 0) p = [""]
        pages = p
        var s = schedules.slice()
        s.splice(cur, 1)
        if (s.length === 0) s = [{}]
        schedules = s
        go(Math.min(cur, pages.length - 1))
    }

    Process {
        running: true
        command: ["mkdir", "-p", root.dir]
    }

    Timer {
        id: saveTimer
        interval: 500
        onTriggered: file.setText(JSON.stringify({ pages: root.pages, schedules: root.schedules, cur: root.cur }))
    }

    FileView {
        id: file
        path: root.dir + "/notes.json"
        onLoaded: {
            try {
                var d = JSON.parse(text())
                if (d.pages && d.pages.length > 0) {
                    root.pages = d.pages
                    root.schedules = d.schedules || d.pages.map(function() { return {} })
                    root.cur = Math.min(d.cur || 0, d.pages.length - 1)
                }
            } catch (e) {}
            root.go(root.cur)
        }
    }

    FileView {
        id: eventFile
        path: ""
    }

    FileView {
        id: sharedEventsFile
        path: root.sharedEventsPath
        watchChanges: true
        onLoaded: {
            try {
                var data = JSON.parse(text())
                root.sharedEvents = data.events || {}
                root.sharedEventTimes = data.eventTimes || {}
            } catch (e) {}
        }
        onFileChanged: sharedEventsReloadTimer.restart()
    }

    Timer {
        id: sharedEventsReloadTimer
        interval: 100
        onTriggered: sharedEventsFile.reload()
    }

    FileView {
        id: focusFile
        path: root.focusPath
        watchChanges: true
        onLoaded: {
            var value = text().trim() || "none"
            if (root.activeWidget !== value) root.activeWidget = value
            if (value === "notes" && !root.isLarge && !root.settingsOpen) root.syncWidgetFocus()
            if (value === "none" && (root.isLarge || root.settingsOpen)) root.syncWidgetFocus()
        }
        onFileChanged: focusReloadTimer.restart()
    }

    Timer {
        id: focusReloadTimer
        interval: 100
        onTriggered: focusFile.reload()
    }

    Process {
        id: openCalendar
        command: ["xdg-open", root.icsPath]
    }

    Timer {
        id: openTimer
        interval: 250
        onTriggered: openCalendar.running = true
    }

    Rectangle {
        anchors.fill: parent
        anchors.topMargin: 3
        radius: 4
        color: "#061217"
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: root.panelColor }
            GradientStop { position: 0.45; color: root.bgColor }
            GradientStop { position: 1; color: Qt.darker(root.bgColor, 1.12) }
        }
        border.color: Qt.darker(root.accent, 2.2)
        border.width: 1
        radius: 3

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: root.isLarge || root.settingsOpen ? 12 : 3
            spacing: root.isLarge || root.settingsOpen ? 8 : 2
            visible: !root.settingsOpen

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: !root.isLarge
                spacing: root.isLarge ? 8 : 2

                Rectangle {
                    Layout.preferredWidth: root.isLarge ? 30 : 26
                    Layout.fillHeight: !root.isLarge
                    Layout.preferredHeight: root.isLarge ? 30 : 0
                    radius: 4
                    color: root.panelColor
                    Text { anchors.centerIn: parent; text: "N"; color: root.accent; font.pixelSize: root.isLarge ? 16 : 12; font.bold: true }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: root.isLarge ? 2 : 1
                    Text {
                        Layout.fillWidth: true
                        text: root.isLarge ? "FIELD NOTES" : (titleField.text || "NOTES")
                        color: root.textColor
                        font.pixelSize: root.isLarge ? 13 : 8
                        font.bold: true
                        elide: Text.ElideRight
                    }
                    Text {
                        Layout.fillWidth: true
                        text: root.isLarge ? ((root.cur + 1) + " / " + root.pages.length) : (editor.text.trim() || "No note yet")
                        color: root.dimColor
                        font.pixelSize: root.isLarge ? 9 : 7
                        elide: Text.ElideRight
                    }
                }
                NoteButton {
                    label: root.isLarge ? "<" : "+"
                    hint: root.isLarge ? "Previous note" : "Expand notes"
                    compact: !root.isLarge
                    visible: !root.isLarge || root.pages.length > 1
                    onClicked: root.isLarge ? root.go(root.cur - 1) : root.isLarge = true
                }
                NoteButton {
                    label: root.isLarge ? ">" : "S"
                    hint: root.isLarge ? "Next note" : "Settings"
                    compact: !root.isLarge
                    onClicked: root.isLarge ? root.go(root.cur + 1) : root.settingsOpen = true
                }
                NoteButton {
                    label: "-"
                    hint: "Collapse notes"
                    visible: root.isLarge
                    onClicked: root.isLarge = false
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: root.borderColor; visible: root.isLarge }

            TextField {
                id: titleField
                Layout.fillWidth: true
                visible: root.isLarge
                placeholderText: "Note title"
                color: root.textColor
                placeholderTextColor: root.dimColor
                font.pixelSize: 15
                font.bold: true
                leftPadding: 0
                background: null
                onTextChanged: root.updateSchedule()
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.isLarge
                color: root.panelColor
                radius: 4
                border.color: root.borderColor
                TextArea {
                    id: editor
                    anchors.fill: parent
                    anchors.margins: 9
                    color: root.textColor
                    selectionColor: root.accent
                    selectedTextColor: root.bgColor
                    placeholderText: "Write a note..."
                    placeholderTextColor: root.dimColor
                    font.pixelSize: 12
                    wrapMode: TextEdit.Wrap
                    background: null
                    padding: 0
                    onTextChanged: {
                        if (root.loading) return
                        var p = root.pages.slice()
                        p[root.cur] = text
                        root.pages = p
                        root.save()
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: root.scheduleOpen ? 184 : 34
                visible: root.isLarge
                color: root.panelColor
                radius: 4
                border.color: root.borderColor

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 7
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: root.scheduleOpen ? "ADD TO CALENDAR" : "CALENDAR"; color: root.accent; font.pixelSize: 9; font.bold: true; font.letterSpacing: 1 }
                        Item { Layout.fillWidth: true }
                        Text { text: root.scheduleOpen ? "1 HOUR" : root.scheduleSummary(); color: root.dimColor; font.pixelSize: 8; font.letterSpacing: 1 }
                        NoteButton {
                            label: root.scheduleOpen ? "-" : "+"
                            hint: root.scheduleOpen ? "Hide scheduling" : "Add a calendar event"
                            compact: true
                            onClicked: root.scheduleOpen = !root.scheduleOpen
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 7
                        visible: root.scheduleOpen
                        ScheduleSelector {
                            id: monthField
                            Layout.fillWidth: true
                            model: root.monthOptions
                            currentIndex: root.selectedMonth
                            onActivated: {
                                root.selectedMonth = currentIndex
                                root.selectedDay = Math.min(root.selectedDay, new Date(root.selectedYear, root.selectedMonth + 1, 0).getDate())
                                root.updateSchedule()
                            }
                        }
                        ScheduleSelector {
                            id: dayField
                            Layout.preferredWidth: 52
                            model: root.dayOptions
                            currentIndex: root.selectedDay - 1
                            onActivated: { root.selectedDay = Number(currentText); root.updateSchedule() }
                        }
                        ScheduleSelector {
                            id: yearField
                            Layout.preferredWidth: 72
                            model: root.yearOptions
                            currentIndex: Math.max(0, root.yearOptions.indexOf(root.selectedYear))
                            onActivated: {
                                root.selectedYear = Number(currentText)
                                root.selectedDay = Math.min(root.selectedDay, new Date(root.selectedYear, root.selectedMonth + 1, 0).getDate())
                                root.updateSchedule()
                            }
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 7
                        visible: root.scheduleOpen
                        ScheduleSelector {
                            id: hourField
                            Layout.fillWidth: true
                            model: root.hourOptions
                            currentIndex: (root.selectedHour + 11) % 12
                            onActivated: {
                                root.selectedHour = (root.selectedHour >= 12 ? 12 : 0) + (Number(currentText) % 12)
                                root.updateSchedule()
                            }
                        }
                        ScheduleSelector {
                            id: minuteField
                            Layout.fillWidth: true
                            model: root.minuteOptions
                            currentIndex: root.selectedMinute
                            onActivated: { root.selectedMinute = Number(currentText); root.updateSchedule() }
                        }
                        ScheduleSelector {
                            id: meridiemField
                            Layout.preferredWidth: 62
                            model: ["AM", "PM"]
                            currentIndex: root.selectedHour >= 12 ? 1 : 0
                            onActivated: {
                                root.selectedHour = (index === 1 ? 12 : 0) + (root.selectedHour % 12)
                                root.updateSchedule()
                            }
                        }
                    }
                    Button {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 34
                        visible: root.scheduleOpen
                        text: "Create calendar event"
                        onClicked: root.createCalendarEvent()
                        contentItem: Text { text: parent.text; color: root.bgColor; font.pixelSize: 11; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        background: Rectangle { radius: 4; color: parent.down ? Qt.lighter(root.accent, 1.1) : root.accent }
                    }
                    Text { Layout.fillWidth: true; visible: root.scheduleOpen; text: root.statusText; color: root.dimColor; font.pixelSize: 9; elide: Text.ElideRight }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                visible: root.isLarge
                Text { text: "NOTE " + (root.cur + 1) + " / " + root.pages.length; color: root.dimColor; font.pixelSize: 9 }
                Item { Layout.fillWidth: true }
                NoteButton { label: "+"; hint: "New note"; onClicked: root.addPage() }
                NoteButton { label: "X"; hint: "Delete note"; danger: true; onClicked: root.deletePage() }
            }
        }

        NoteCornerFrame {
            anchors.fill: parent
            anchors.margins: 1
            color: root.accent
            pulse: root.framePulse
        }
    }

    Rectangle {
        anchors.fill: parent
        visible: root.settingsOpen
        color: root.bgColor
        border.color: root.borderColor
        radius: 4

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 7

            RowLayout {
                Layout.fillWidth: true
                Text { Layout.fillWidth: true; text: "Widget location"; color: root.textColor; font.pixelSize: 11; font.bold: true }
                NoteButton { label: "X"; hint: "Close settings"; compact: true; onClicked: root.settingsOpen = false }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 4
                rowSpacing: 4
                columnSpacing: 4
                Repeater {
                    model: ["top-left", "top-right", "bottom-left", "bottom-right"]
                    NoteButton {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 24
                        label: modelData === "top-left" ? "TL" : modelData === "top-right" ? "TR" : modelData === "bottom-left" ? "BL" : "BR"
                        hint: modelData
                        highlighted: root.anchorCorner === modelData
                        onClicked: root.anchorCorner = modelData
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Text { Layout.fillWidth: true; text: "X offset"; color: root.dimColor; font.pixelSize: 9 }
                NoteButton { label: "-"; compact: true; onClicked: root.offsetX = Math.max(0, root.offsetX - 16) }
                Text { Layout.preferredWidth: 26; horizontalAlignment: Text.AlignHCenter; text: root.offsetX; color: root.textColor; font.pixelSize: 9 }
                NoteButton { label: "+"; compact: true; onClicked: root.offsetX = Math.min(600, root.offsetX + 16) }
            }
            RowLayout {
                Layout.fillWidth: true
                Text { Layout.fillWidth: true; text: "Y offset"; color: root.dimColor; font.pixelSize: 9 }
                NoteButton { label: "-"; compact: true; onClicked: root.offsetY = Math.max(0, root.offsetY - 16) }
                Text { Layout.preferredWidth: 26; horizontalAlignment: Text.AlignHCenter; text: root.offsetY; color: root.textColor; font.pixelSize: 9 }
                NoteButton { label: "+"; compact: true; onClicked: root.offsetY = Math.min(600, root.offsetY + 16) }
            }
        }
    }

    component ScheduleSelector: ComboBox {
        id: selector
        implicitHeight: 32
        font.family: "monospace"
        font.pixelSize: 10
        leftPadding: 8
        rightPadding: 6
        contentItem: Text {
            leftPadding: 8
            rightPadding: 18
            text: selector.displayText
            color: root.textColor
            font: selector.font
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
        indicator: Text {
            text: "v"
            color: root.accent
            font.pixelSize: 9
            anchors.right: parent.right
            anchors.rightMargin: 7
            anchors.verticalCenter: parent.verticalCenter
        }
        background: Rectangle {
            radius: 3
            border.color: selector.activeFocus ? root.accent : root.borderColor
            gradient: Gradient {
                GradientStop { position: 0; color: root.panelColor }
                GradientStop { position: 1; color: root.bgColor }
            }
        }
        delegate: ItemDelegate {
            width: selector.width
            contentItem: Text {
                text: selector.textAt(index)
                color: root.textColor
                font: selector.font
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }
            background: Rectangle {
                color: highlighted ? Qt.lighter(root.panelColor, 1.2) : root.panelColor
                radius: 2
            }
        }
        popup: Popup {
            y: selector.height
            width: selector.width
            implicitHeight: Math.min(contentItem.implicitHeight, 180) + padding * 2
            padding: 3
            contentItem: ListView {
                clip: true
                implicitHeight: contentHeight
                model: selector.popup.visible ? selector.delegateModel : null
                currentIndex: selector.highlightedIndex
                ScrollIndicator.vertical: ScrollIndicator {}
            }
            background: Rectangle {
                color: root.panelColor
                border.color: root.borderColor
                radius: 3
            }
        }
    }

    component NoteButton: Item {
        id: btn
        property string label: ""
        property string hint: ""
        property bool danger: false
        property bool compact: false
        property bool highlighted: false
        signal clicked()

        Layout.preferredWidth: compact ? 14 : 26
        Layout.preferredHeight: compact ? 20 : 26
        y: pointer.pressed ? 2 : 0
        scale: pointer.pressed ? 0.97 : (pointer.containsMouse ? 1.03 : 1)

        Behavior on y { NumberAnimation { duration: 75; easing.type: Easing.OutCubic } }
        Behavior on scale { SpringAnimation { spring: 3.5; damping: 0.36 } }

        Rectangle {
            anchors.fill: parent
            anchors.topMargin: 2
            radius: 3
            color: "#061217"
        }

        Rectangle {
            anchors.fill: parent
            anchors.bottomMargin: pointer.pressed ? 0 : 3
            radius: 3
            border.width: 1
            border.color: pointer.pressed ? root.accent : Qt.darker(root.borderColor, 1.18)
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: btn.highlighted ? Qt.lighter(root.accent, 1.12)
                                            : Qt.lighter(pointer.containsMouse ? "#24515c" : root.panelColor, 1.28)
                }
                GradientStop {
                    position: 0.42
                    color: btn.highlighted ? root.accent : (pointer.containsMouse ? "#24515c" : root.panelColor)
                }
                GradientStop {
                    position: 1
                    color: btn.highlighted ? Qt.darker(root.accent, 1.18) : Qt.darker(root.panelColor, 1.28)
                }
            }
        }

        ToolTip.visible: pointer.containsMouse && btn.hint !== ""
        ToolTip.text: btn.hint
        ToolTip.delay: 500

        Text {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: pointer.pressed ? 1 : -1
            text: btn.label
            color: pointer.containsMouse || btn.highlighted ? root.accent : root.textColor
            font.pixelSize: btn.compact ? 8 : 12
            font.bold: true
        }
        MouseArea {
            id: pointer
            anchors.fill: parent
            hoverEnabled: true
            onClicked: btn.clicked()
        }
    }

    component NoteCornerFrame: Item {
        property color color: root.accent
        property real pulse: 1
        readonly property color edgeColor: Qt.darker(color, 2.2)

        Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.color: parent.edgeColor
            border.width: 1
            radius: 2
        }
        Rectangle { width: 10; height: 1; anchors.left: parent.left; anchors.top: parent.top; anchors.margins: 3; color: parent.color; opacity: 0.35 + parent.pulse * 0.5 }
        Rectangle { width: 1; height: 10; anchors.left: parent.left; anchors.top: parent.top; anchors.margins: 3; color: parent.color; opacity: 0.35 + parent.pulse * 0.5 }
        Rectangle { width: 10; height: 1; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 3; color: parent.color; opacity: 0.35 + parent.pulse * 0.5 }
        Rectangle { width: 1; height: 10; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 3; color: parent.color; opacity: 0.35 + parent.pulse * 0.5 }
        Rectangle { width: 10; height: 1; anchors.left: parent.left; anchors.bottom: parent.bottom; anchors.margins: 3; color: parent.color; opacity: 0.35 + parent.pulse * 0.5 }
        Rectangle { width: 1; height: 10; anchors.left: parent.left; anchors.bottom: parent.bottom; anchors.margins: 3; color: parent.color; opacity: 0.35 + parent.pulse * 0.5 }
        Rectangle { width: 10; height: 1; anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 3; color: parent.color; opacity: 0.35 + parent.pulse * 0.5 }
        Rectangle { width: 1; height: 10; anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 3; color: parent.color; opacity: 0.35 + parent.pulse * 0.5 }
    }
}