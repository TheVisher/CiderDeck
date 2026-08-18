import QtQuick

Card {
    id: weatherTile

    property string tileId: parent ? parent.tileId : ""
    property string sizeClass: parent ? parent.sizeClass : "small"
    property var settings: parent ? parent.settings : ({})
    property bool contentEditMode: parent ? parent.contentEditMode : false
    property string selectedElement: parent ? parent.selectedContentElement : ""
    readonly property real contentScale: parent ? (parent.contentScale || 1) : 1
    readonly property real iconScale: Math.sqrt(contentScale)
    readonly property real decorationScale: Math.min(contentScale, 1.5)
    readonly property bool showIcon: settings.showIcon !== false
    readonly property bool showCondition: settings.showCondition !== false
    readonly property bool showWind: settings.showWind !== false
    readonly property bool showLocation: settings.showLocation !== false
    readonly property var customLayout: settings.weatherLayout || ({})
    readonly property Item contentCanvas: weatherCanvas

    property string dragElementId: ""
    property var dragItem: null
    property real dragOffsetX: 0
    property real dragOffsetY: 0
    property real dragStartX: 0
    property real dragStartY: 0
    property bool dragValid: true

    readonly property var elementIds: [
        "header", "location", "weatherIcon", "temperature", "condition", "wind", "humidity"
    ]

    function elementDisplayName(elementId) {
        switch (elementId) {
        case "weatherIcon": return "Icon"
        case "temperature": return "Temperature"
        case "condition": return "Condition"
        case "wind": return "Wind"
        case "humidity": return "Humidity"
        case "location": return "Location"
        default: return "Header"
        }
    }

    function defaultElement(elementId) {
        switch (elementId) {
        case "header":      return { x: 0.02, y: 0.03, scale: 1, textScale: 1 }
        case "location":    return { x: 0.72, y: 0.03, scale: 1, textScale: 1 }
        case "weatherIcon": return { x: 0.03, y: 0.31, scale: 1, textScale: 1 }
        case "temperature": return { x: 0.26, y: 0.24, scale: 1, textScale: 1 }
        case "condition":   return { x: 0.26, y: 0.67, scale: 1, textScale: 1 }
        case "wind":        return { x: 0.68, y: 0.30, scale: 1, textScale: 1 }
        case "humidity":    return { x: 0.86, y: 0.30, scale: 1, textScale: 1 }
        default:             return { x: 0, y: 0, scale: 1, textScale: 1 }
        }
    }

    function elementValue(elementId, key) {
        var defaults = defaultElement(elementId)
        var saved = customLayout[elementId] || ({})
        return saved[key] !== undefined ? Number(saved[key]) : defaults[key]
    }

    function elementX(elementId) { return elementValue(elementId, "x") * weatherCanvas.width }
    function elementY(elementId) { return elementValue(elementId, "y") * weatherCanvas.height }
    function elementScale(elementId) { return Math.max(0.5, Math.min(3, elementValue(elementId, "scale"))) }
    function elementTextScale(elementId) { return Math.max(0.5, Math.min(3, elementValue(elementId, "textScale"))) }
    function elementFontScale(elementId) { return elementScale(elementId) * elementTextScale(elementId) }

    function elementVisible(elementId) {
        var saved = customLayout[elementId] || ({})
        if (saved.visible !== undefined) return Boolean(saved.visible)
        if (elementId === "location") return showLocation
        if (elementId === "weatherIcon") return showIcon
        if (elementId === "condition") return showCondition
        if (elementId === "wind" || elementId === "humidity") return showWind
        return true
    }

    function elementItem(elementId) {
        switch (elementId) {
        case "header": return headerItem
        case "location": return locationItem
        case "weatherIcon": return weatherIconItem
        case "temperature": return temperatureItem
        case "condition": return conditionItem
        case "wind": return windItem
        case "humidity": return humidityItem
        }
        return null
    }

    function visualRect(item) {
        var point = item.mapToItem(weatherCanvas, 0, 0)
        return { x: point.x, y: point.y, width: item.width * item.scale, height: item.height * item.scale }
    }

    function rectanglesOverlap(first, second, gap) {
        return first.x < second.x + second.width + gap
            && first.x + first.width + gap > second.x
            && first.y < second.y + second.height + gap
            && first.y + first.height + gap > second.y
    }

    function rectInsideCanvas(rect) {
        return rect.x >= 0 && rect.y >= 0
            && rect.x + rect.width <= weatherCanvas.width
            && rect.y + rect.height <= weatherCanvas.height
    }

    function placementValid(elementId, rect) {
        if (!rectInsideCanvas(rect)) return false
        for (var i = 0; i < elementIds.length; ++i) {
            var otherId = elementIds[i]
            if (otherId === elementId || !elementVisible(otherId)) continue
            var other = elementItem(otherId)
            if (other && rectanglesOverlap(rect, visualRect(other), 7)) return false
        }
        return true
    }

    function predictedRectsValid(candidateScale, changedElement, changedRatio) {
        var predicted = []
        var currentGlobal = Math.max(0.01, contentScale)
        for (var i = 0; i < elementIds.length; ++i) {
            var elementId = elementIds[i]
            if (!elementVisible(elementId)) continue
            var item = elementItem(elementId)
            if (!item) continue
            var rect = visualRect(item)
            var growth = elementId === "weatherIcon"
                       ? Math.sqrt(candidateScale / currentGlobal)
                       : candidateScale / currentGlobal
            if (elementId === changedElement)
                growth *= changedRatio
            rect.width *= growth
            rect.height *= growth
            if (!rectInsideCanvas(rect)) return false
            predicted.push(rect)
        }
        for (var first = 0; first < predicted.length; ++first) {
            for (var second = first + 1; second < predicted.length; ++second) {
                if (rectanglesOverlap(predicted[first], predicted[second], 7)) return false
            }
        }
        return true
    }

    function predictedElementValid(elementId, changedRatio) {
        var item = elementItem(elementId)
        if (!item || !elementVisible(elementId)) return true

        var rect = visualRect(item)
        rect.width *= changedRatio
        rect.height *= changedRatio
        if (!rectInsideCanvas(rect)) return false

        for (var i = 0; i < elementIds.length; ++i) {
            var otherId = elementIds[i]
            if (otherId === elementId || !elementVisible(otherId)) continue
            var other = elementItem(otherId)
            if (other && rectanglesOverlap(rect, visualRect(other), 7)) return false
        }
        return true
    }

    function largestSafeValue(requested, testFunction) {
        if (testFunction(requested)) return requested
        var low = 0.5
        var high = requested
        if (!testFunction(low)) return 0.5
        for (var i = 0; i < 14; ++i) {
            var middle = (low + high) / 2
            if (testFunction(middle)) low = middle
            else high = middle
        }
        return Math.floor(low * 20) / 20
    }

    function safeGlobalScale(requested) {
        var bounded = Math.max(0.5, Math.min(3, requested))
        var accepted = largestSafeValue(bounded, function(value) {
            return predictedRectsValid(value, "", 1)
        })
        root.contentEditConstraint = accepted + 0.001 < bounded
                                   ? "Maximum safe scale for this layout: " + Math.round(accepted * 100) + "%"
                                   : ""
        return accepted
    }

    function safeItemValue(elementId, key, requested) {
        var currentValue = Math.max(0.01, elementValue(elementId, key))
        var bounded = Math.max(0.5, Math.min(3, requested))
        var accepted = largestSafeValue(bounded, function(value) {
            // Only the selected element is changing. Existing collisions among
            // other items should not prevent the user from fixing that layout.
            return predictedElementValid(elementId, value / currentValue)
        })
        root.contentEditConstraint = accepted + 0.001 < bounded
                                   ? "Move nearby items to make more room"
                                   : ""
        return accepted
    }

    function installValidators() {
        if (!contentEditMode
                && !(settingsPanel.isOpen && settingsPanel.editingTileId === tileId)) return
        root.contentValidatorOwner = tileId
        root.contentScaleValidator = function(value) { return weatherTile.safeGlobalScale(value) }
        root.contentItemValueValidator = function(elementId, key, value) {
            return weatherTile.safeItemValue(elementId, key, value)
        }
    }

    onContentEditModeChanged: {
        if (contentEditMode) installValidators()
        else if (!(settingsPanel.isOpen && settingsPanel.editingTileId === tileId)) {
            root.clearContentValidators(tileId)
        }
    }

    Connections {
        target: settingsPanel
        function onIsOpenChanged() {
            if (settingsPanel.isOpen && settingsPanel.editingTileId === weatherTile.tileId)
                weatherTile.installValidators()
            else if (!weatherTile.contentEditMode) {
                root.clearContentValidators(weatherTile.tileId)
            }
        }
        function onEditingTileIdChanged() {
            if (settingsPanel.isOpen && settingsPanel.editingTileId === weatherTile.tileId)
                weatherTile.installValidators()
            else if (!weatherTile.contentEditMode)
                root.clearContentValidators(weatherTile.tileId)
        }
    }
    Component.onCompleted: {
        if (contentEditMode) installValidators()
        applyWeatherSettings()
    }
    Component.onDestruction: {
        root.clearContentValidators(tileId)
    }

    function saveLayout(layout) {
        var newSettings = Object.assign({}, settings)
        newSettings.weatherLayout = layout
        deckConfig.updateTile(tileId, { settings: newSettings })
    }

    function saveElementPosition(elementId, item) {
        var layout = JSON.parse(JSON.stringify(customLayout || ({})))
        var element = Object.assign({}, layout[elementId] || ({}))
        element.x = Math.round((item.x / weatherCanvas.width) * 10000) / 10000
        element.y = Math.round((item.y / weatherCanvas.height) * 10000) / 10000
        layout[elementId] = element
        saveLayout(layout)
    }

    function beginElementDrag(elementId, item, pointerX, pointerY) {
        root.contentEditElement = elementId
        dragElementId = elementId
        dragItem = item
        dragStartX = item.x
        dragStartY = item.y
        dragOffsetX = pointerX - item.x
        dragOffsetY = pointerY - item.y
        dragValid = true
    }

    function updateElementDrag(pointerX, pointerY) {
        if (!dragItem) return
        var visualWidth = dragItem.width * dragItem.scale
        var visualHeight = dragItem.height * dragItem.scale
        dragItem.x = Math.max(0, Math.min(weatherCanvas.width - visualWidth, pointerX - dragOffsetX))
        dragItem.y = Math.max(0, Math.min(weatherCanvas.height - visualHeight, pointerY - dragOffsetY))
        dragValid = placementValid(dragElementId,
            { x: dragItem.x, y: dragItem.y, width: visualWidth, height: visualHeight })
    }

    function endElementDrag() {
        if (!dragItem) return
        if (dragValid) {
            root.contentEditConstraint = ""
            saveElementPosition(dragElementId, dragItem)
        } else {
            dragItem.x = dragStartX
            dragItem.y = dragStartY
            root.contentEditConstraint = "Items cannot overlap"
        }
        dragItem = null
        dragElementId = ""
    }

    function cancelElementDrag() {
        if (dragItem) {
            dragItem.x = dragStartX
            dragItem.y = dragStartY
        }
        dragItem = null
        dragElementId = ""
        dragValid = true
    }

    function applyWeatherSettings() {
        if (settings.location && settings.location !== "")
            weatherService.setLocations([settings.location])
        else if (settings.locations && settings.locations.length > 0)
            weatherService.setLocations(settings.locations)
        else
            weatherService.setLocations([])
        if (settings.unit) weatherService.setUnit(settings.unit)
        if (settings.refreshMinutes) weatherService.setRefreshInterval(settings.refreshMinutes)
    }

    onSettingsChanged: {
        if (settings.unit) weatherService.setUnit(settings.unit)
        if (settings.refreshMinutes) weatherService.setRefreshInterval(settings.refreshMinutes)
        if (settings.location !== undefined) {
            weatherService.setLocations(settings.location !== "" ? [settings.location] : [])
        }
        if (contentEditMode) Qt.callLater(installValidators)
    }

    Item {
        id: weatherCanvas
        anchors.fill: parent
        anchors.margins: 14

        Item {
            id: headerItem
            x: weatherTile.elementX("header")
            y: weatherTile.elementY("header")
            width: headerRow.implicitWidth
            height: headerRow.implicitHeight
            visible: weatherTile.elementVisible("header")
            z: weatherTile.selectedElement === "header" ? 20 : 1

            Row {
                id: headerRow
                spacing: 8 * weatherTile.elementScale("header")
                Rectangle {
                    width: 5 * weatherTile.elementScale("header")
                    height: 18 * weatherTile.decorationScale * weatherTile.elementScale("header")
                    radius: 2 * weatherTile.elementScale("header")
                    color: "#f6c85f"
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: "CURRENT CONDITIONS"
                    color: themeManager.secondaryTextColor
                    font.pixelSize: 11 * weatherTile.contentScale * weatherTile.elementFontScale("header")
                    font.weight: Font.DemiBold
                    renderType: Text.NativeRendering
                }
            }
            WeatherEditableFrame { host: weatherTile; elementId: "header" }
        }

        Item {
            id: locationItem
            x: weatherTile.elementX("location")
            y: weatherTile.elementY("location")
            width: locationText.implicitWidth
            height: locationText.implicitHeight
            visible: weatherTile.elementVisible("location")
            z: weatherTile.selectedElement === "location" ? 20 : 1
            Text {
                id: locationText
                text: weatherService.location || ""
                color: themeManager.secondaryTextColor
                font.pixelSize: 11 * weatherTile.contentScale * weatherTile.elementFontScale("location")
                renderType: Text.NativeRendering
            }
            WeatherEditableFrame { host: weatherTile; elementId: "location" }
        }

        Item {
            id: weatherIconItem
            x: weatherTile.elementX("weatherIcon")
            y: weatherTile.elementY("weatherIcon")
            width: Math.min(130, 80 * weatherTile.iconScale)
                   * weatherTile.elementScale("weatherIcon")
            height: width
            visible: weatherTile.elementVisible("weatherIcon")
            z: weatherTile.selectedElement === "weatherIcon" ? 20 : 1
            LucideIcon {
                anchors.fill: parent
                source: weatherService.icon
                        ? "qrc:/icons/lucide/" + weatherService.icon + ".svg"
                        : "qrc:/icons/lucide/cloud-sun.svg"
                color: "#f6c85f"
            }
            WeatherEditableFrame { host: weatherTile; elementId: "weatherIcon" }
        }

        Item {
            id: temperatureItem
            x: weatherTile.elementX("temperature")
            y: weatherTile.elementY("temperature")
            width: temperatureText.implicitWidth
            height: temperatureText.implicitHeight
            visible: weatherTile.elementVisible("temperature")
            z: weatherTile.selectedElement === "temperature" ? 20 : 1
            Text {
                id: temperatureText
                text: weatherService.temperature || "--"
                color: themeManager.textColor
                font.pixelSize: 48 * weatherTile.contentScale * weatherTile.elementFontScale("temperature")
                font.weight: Font.DemiBold
                renderType: Text.NativeRendering
            }
            WeatherEditableFrame { host: weatherTile; elementId: "temperature" }
        }

        Item {
            id: conditionItem
            x: weatherTile.elementX("condition")
            y: weatherTile.elementY("condition")
            // Short phrases such as "Sunny" should not reserve the same wide
            // collision box needed by "Scattered thunderstorms". Hug the
            // rendered text while retaining a cap and ellipsis for long copy.
            width: Math.min(conditionText.implicitWidth,
                            Math.min(210, weatherCanvas.width * 0.40)
                            * weatherTile.elementScale("condition"))
            height: conditionText.implicitHeight
            visible: weatherTile.elementVisible("condition")
            z: weatherTile.selectedElement === "condition" ? 20 : 1
            Text {
                id: conditionText
                width: parent.width
                text: weatherService.condition || "Updating"
                color: themeManager.secondaryTextColor
                font.pixelSize: 15 * weatherTile.contentScale * weatherTile.elementFontScale("condition")
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
                renderType: Text.NativeRendering
            }
            WeatherEditableFrame { host: weatherTile; elementId: "condition" }
        }

        Item {
            id: windItem
            x: weatherTile.elementX("wind")
            y: weatherTile.elementY("wind")
            width: windColumn.implicitWidth
            height: windColumn.implicitHeight
            visible: weatherTile.elementVisible("wind")
            z: weatherTile.selectedElement === "wind" ? 20 : 1
            Column {
                id: windColumn
                spacing: 8 * weatherTile.elementScale("wind")
                LucideIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 27 * weatherTile.iconScale * weatherTile.elementScale("wind")
                    height: width
                    source: "qrc:/icons/lucide/wind.svg"
                    color: "#76c7f2"
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: weatherService.windSpeed || "--"
                    color: themeManager.textColor
                    font.pixelSize: 16 * weatherTile.contentScale * weatherTile.elementFontScale("wind")
                    font.weight: Font.DemiBold
                    renderType: Text.NativeRendering
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "WIND"
                    color: themeManager.secondaryTextColor
                    font.pixelSize: 9 * weatherTile.contentScale * weatherTile.elementFontScale("wind")
                    font.weight: Font.DemiBold
                    renderType: Text.NativeRendering
                }
            }
            WeatherEditableFrame { host: weatherTile; elementId: "wind" }
        }

        Item {
            id: humidityItem
            x: weatherTile.elementX("humidity")
            y: weatherTile.elementY("humidity")
            width: humidityColumn.implicitWidth
            height: humidityColumn.implicitHeight
            visible: weatherTile.elementVisible("humidity")
            z: weatherTile.selectedElement === "humidity" ? 20 : 1
            Column {
                id: humidityColumn
                spacing: 8 * weatherTile.elementScale("humidity")
                LucideIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 27 * weatherTile.iconScale * weatherTile.elementScale("humidity")
                    height: width
                    source: "qrc:/icons/lucide/droplets.svg"
                    color: "#5dd6c0"
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: weatherService.humidity || "--"
                    color: themeManager.textColor
                    font.pixelSize: 16 * weatherTile.contentScale * weatherTile.elementFontScale("humidity")
                    font.weight: Font.DemiBold
                    renderType: Text.NativeRendering
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "HUMIDITY"
                    color: themeManager.secondaryTextColor
                    font.pixelSize: 9 * weatherTile.contentScale * weatherTile.elementFontScale("humidity")
                    font.weight: Font.DemiBold
                    renderType: Text.NativeRendering
                }
            }
            WeatherEditableFrame { host: weatherTile; elementId: "humidity" }
        }
    }

    MouseArea {
        anchors.fill: parent
        z: -1
        enabled: !weatherTile.contentEditMode
        property real startX: 0
        onPressed: (mouse) => startX = mouse.x
        onReleased: (mouse) => {
            var delta = mouse.x - startX
            if (delta < -60) weatherService.nextLocation()
            else if (delta > 60) weatherService.previousLocation()
        }
    }
}
