import QtQuick

Item {
    id: controller

    required property Item tile
    required property Item canvas
    required property string tileId
    required property var settings
    required property var elements
    required property var itemForId
    property string layoutKey: "contentLayout"
    property bool contentEditMode: false
    property string selectedElement: ""
    property real contentScale: 1
    property bool guardGlobalScale: true
    readonly property bool allowOverlap: settings.allowContentOverlap === true

    width: 0
    height: 0
    visible: false

    readonly property var customLayout: settings[layoutKey] || ({})
    readonly property var elementIds: elements.map(function(element) { return element.id })

    property string dragElementId: ""
    property var dragItem: null
    property real dragOffsetX: 0
    property real dragOffsetY: 0
    property real dragStartX: 0
    property real dragStartY: 0
    property bool dragValid: true
    property bool showVerticalGuide: false
    property bool showHorizontalGuide: false
    property real guideX: canvas.width / 2
    property real guideY: canvas.height / 2
    property real snapDistance: 10

    function descriptor(elementId) {
        for (var i = 0; i < elements.length; ++i) {
            if (elements[i].id === elementId) return elements[i]
        }
        return { id: elementId, label: elementId, x: 0, y: 0,
                 scale: 1, textScale: 1, visible: true, hasText: true }
    }

    function elementDisplayName(elementId) {
        return descriptor(elementId).label || elementId
    }

    function elementValue(elementId, key) {
        var defaults = descriptor(elementId)
        var saved = customLayout[elementId] || ({})
        if (saved[key] !== undefined) return Number(saved[key])
        return defaults[key] !== undefined ? Number(defaults[key]) : 1
    }

    function hasSavedValue(elementId, key) {
        var saved = customLayout[elementId] || ({})
        return saved[key] !== undefined
    }

    function elementX(elementId) { return elementValue(elementId, "x") * canvas.width }
    function elementY(elementId) { return elementValue(elementId, "y") * canvas.height }
    function elementScale(elementId) {
        return Math.max(0.5, Math.min(3, elementValue(elementId, "scale")))
    }
    function elementTextScale(elementId) {
        return Math.max(0.5, Math.min(3, elementValue(elementId, "textScale")))
    }
    function elementFontScale(elementId) {
        return elementScale(elementId) * elementTextScale(elementId)
    }
    function elementVisible(elementId) {
        var saved = customLayout[elementId] || ({})
        if (saved.visible !== undefined) return Boolean(saved.visible)
        return descriptor(elementId).visible !== false
    }
    function elementItem(elementId) { return itemForId(elementId) }

    function visualRect(item) {
        var point = item.mapToItem(canvas, 0, 0)
        return { x: point.x, y: point.y,
                 width: item.width * item.scale, height: item.height * item.scale }
    }

    function rectanglesOverlap(first, second, gap) {
        return first.x < second.x + second.width + gap
            && first.x + first.width + gap > second.x
            && first.y < second.y + second.height + gap
            && first.y + first.height + gap > second.y
    }

    function rectInsideCanvas(rect) {
        return rect.x >= 0 && rect.y >= 0
            && rect.x + rect.width <= canvas.width
            && rect.y + rect.height <= canvas.height
    }

    function placementValid(elementId, rect) {
        if (!rectInsideCanvas(rect)) return false
        if (allowOverlap || descriptor(elementId).skipCollision === true) return true
        for (var i = 0; i < elementIds.length; ++i) {
            var otherId = elementIds[i]
            if (otherId === elementId || !elementVisible(otherId)) continue
            var other = elementItem(otherId)
            if (other && other.visible
                    && descriptor(otherId).skipCollision !== true
                    && rectanglesOverlap(rect, visualRect(other), 0)) return false
        }
        return true
    }

    function predictedRectsValid(candidateScale) {
        var predicted = []
        var currentGlobal = Math.max(0.01, contentScale)
        for (var i = 0; i < elementIds.length; ++i) {
            var elementId = elementIds[i]
            if (!elementVisible(elementId)) continue
            var item = elementItem(elementId)
            if (!item || !item.visible) continue
            var rect = visualRect(item)
            var mode = descriptor(elementId).globalGrowth || "linear"
            var growth = mode === "none" ? 1
                       : mode === "sqrt"
                         ? Math.sqrt(candidateScale / currentGlobal)
                         : candidateScale / currentGlobal
            rect.width *= growth
            rect.height *= growth
            if (!rectInsideCanvas(rect)) return false
            if (descriptor(elementId).skipCollision !== true)
                predicted.push(rect)
        }
        if (!allowOverlap) {
            for (var first = 0; first < predicted.length; ++first) {
                for (var second = first + 1; second < predicted.length; ++second) {
                    if (rectanglesOverlap(predicted[first], predicted[second], 0)) return false
                }
            }
        }
        return true
    }

    function predictedElementValid(elementId, ratio, growthMode) {
        var item = elementItem(elementId)
        if (!item || !item.visible || !elementVisible(elementId)) return true
        var rect = visualRect(item)
        if (growthMode !== "vertical") rect.width *= ratio
        if (growthMode !== "horizontal") rect.height *= ratio
        return placementValid(elementId, rect)
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
        if (!guardGlobalScale) {
            root.contentEditConstraint = ""
            return bounded
        }
        var accepted = largestSafeValue(bounded, function(value) {
            return controller.predictedRectsValid(value)
        })
        root.contentEditConstraint = accepted + 0.001 < bounded
                                   ? "Maximum safe scale for this layout: "
                                     + Math.round(accepted * 100) + "%"
                                   : ""
        return accepted
    }

    function safeItemValue(elementId, key, requested) {
        var currentValue = Math.max(0.01, elementValue(elementId, key))
        var bounded = Math.max(0.5, Math.min(3, requested))
        var growthMode = key === "textScale"
                       ? descriptor(elementId).textGrowth
                       : descriptor(elementId).itemGrowth
        if (growthMode === "none") {
            root.contentEditConstraint = ""
            return bounded
        }
        var accepted = largestSafeValue(bounded, function(value) {
            return predictedElementValid(elementId, value / currentValue, growthMode)
        })
        root.contentEditConstraint = accepted + 0.001 < bounded
                                   ? "Move nearby items to make more room" : ""
        return accepted
    }

    function installValidators() {
        if (!contentEditMode
                && !(settingsPanel.isOpen && settingsPanel.editingTileId === tileId)) return
        root.contentValidatorOwner = tileId
        root.contentScaleValidator = function(value) {
            return controller.safeGlobalScale(value)
        }
        root.contentItemValueValidator = function(elementId, key, value) {
            return controller.safeItemValue(elementId, key, value)
        }
    }

    function saveLayout(layout) {
        var newSettings = Object.assign({}, settings)
        newSettings[layoutKey] = layout
        deckConfig.updateTile(tileId, { settings: newSettings })
    }

    function saveElementPosition(elementId, item) {
        var layout = JSON.parse(JSON.stringify(customLayout || ({})))
        var element = Object.assign({}, layout[elementId] || ({}))
        element.x = Math.round((item.x / canvas.width) * 10000) / 10000
        element.y = Math.round((item.y / canvas.height) * 10000) / 10000
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
        var nextX = Math.max(0, Math.min(canvas.width - visualWidth,
                                         pointerX - dragOffsetX))
        var nextY = Math.max(0, Math.min(canvas.height - visualHeight,
                                         pointerY - dragOffsetY))
        var centerX = canvas.width / 2
        var centerY = canvas.height / 2
        var bestX = centerX - visualWidth / 2
        var bestY = centerY - visualHeight / 2
        var bestXDistance = Math.abs(nextX - bestX)
        var bestYDistance = Math.abs(nextY - bestY)
        var bestXIsCenter = true
        var bestYIsCenter = true

        // Nearby item edges are snap targets too. Only consider a side when
        // the two items overlap on the perpendicular axis, which avoids
        // pulling content toward unrelated items across the tile.
        for (var i = 0; i < elementIds.length; ++i) {
            var otherId = elementIds[i]
            if (otherId === dragElementId || !elementVisible(otherId)) continue
            var other = elementItem(otherId)
            if (!other || !other.visible || descriptor(otherId).skipCollision === true) continue
            var otherRect = visualRect(other)
            var overlapsVertically = nextY < otherRect.y + otherRect.height
                                   && nextY + visualHeight > otherRect.y
            if (overlapsVertically) {
                var beforeX = otherRect.x - visualWidth
                var afterX = otherRect.x + otherRect.width
                var beforeDistance = Math.abs(nextX - beforeX)
                var afterDistance = Math.abs(nextX - afterX)
                if (beforeX >= 0 && beforeX + visualWidth <= canvas.width
                        && beforeDistance < bestXDistance) {
                    bestX = beforeX
                    bestXDistance = beforeDistance
                    bestXIsCenter = false
                }
                if (afterX >= 0 && afterX + visualWidth <= canvas.width
                        && afterDistance < bestXDistance) {
                    bestX = afterX
                    bestXDistance = afterDistance
                    bestXIsCenter = false
                }
            }

            var overlapsHorizontally = nextX < otherRect.x + otherRect.width
                                     && nextX + visualWidth > otherRect.x
            if (overlapsHorizontally) {
                var aboveY = otherRect.y - visualHeight
                var belowY = otherRect.y + otherRect.height
                var aboveDistance = Math.abs(nextY - aboveY)
                var belowDistance = Math.abs(nextY - belowY)
                if (aboveY >= 0 && aboveY + visualHeight <= canvas.height
                        && aboveDistance < bestYDistance) {
                    bestY = aboveY
                    bestYDistance = aboveDistance
                    bestYIsCenter = false
                }
                if (belowY >= 0 && belowY + visualHeight <= canvas.height
                        && belowDistance < bestYDistance) {
                    bestY = belowY
                    bestYDistance = belowDistance
                    bestYIsCenter = false
                }
            }
        }

        var snapX = bestXDistance <= snapDistance
        var snapY = bestYDistance <= snapDistance
        showVerticalGuide = snapX && bestXIsCenter
        showHorizontalGuide = snapY && bestYIsCenter
        if (snapX) nextX = bestX
        if (snapY) nextY = bestY
        guideX = centerX
        guideY = centerY
        dragItem.x = nextX
        dragItem.y = nextY
        dragValid = placementValid(dragElementId,
            { x: dragItem.x, y: dragItem.y,
              width: visualWidth, height: visualHeight })
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
        showVerticalGuide = false
        showHorizontalGuide = false
    }

    function cancelElementDrag() {
        if (dragItem) {
            dragItem.x = dragStartX
            dragItem.y = dragStartY
        }
        dragItem = null
        dragElementId = ""
        dragValid = true
        showVerticalGuide = false
        showHorizontalGuide = false
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
            if (settingsPanel.isOpen && settingsPanel.editingTileId === controller.tileId)
                controller.installValidators()
            else if (!controller.contentEditMode) {
                root.clearContentValidators(controller.tileId)
            }
        }
        function onEditingTileIdChanged() {
            if (settingsPanel.isOpen && settingsPanel.editingTileId === controller.tileId)
                controller.installValidators()
            else if (!controller.contentEditMode)
                root.clearContentValidators(controller.tileId)
        }
    }

    Component.onCompleted: {
        if (contentEditMode) installValidators()
    }
    Component.onDestruction: {
        root.clearContentValidators(tileId)
    }
}
