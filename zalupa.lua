-- [Оставляем начало файла без изменений до создания TargetInventorySettings]

-- Настройки для TargetInventory
local TargetInventorySettings = {
    ShowNick = false,
    AlwaysVisible = true,
    DistanceLimit = 0,
    TargetMode = "GunSilent Target",
    Enabled = false,
    AppearAnim = true,
    FOV = { Value = 100, Default = 100 },
    ShowCircle = { Value = false, Default = false },
    CircleMethod = { Value = "Middle", Default = "Middle" },
    CircleGradient = { Value = false, Default = false },
    LastTarget = nil,
    LastUpdateTime = 0,
    UpdateInterval = 0.2,
    LastFovUpdateTime = 0,
    FovUpdateInterval = 1/30 -- ~30 FPS для круга FOV
}

-- [Оставляем создание ScreenGui, invScreenGui, invFrame и других UI-элементов без изменений]

-- Функции TargetInventory
local function getItemIcon(itemName)
    local Items = ReplicatedStorage:WaitForChild("Items")
    local GunItems = Items:WaitForChild("gun")
    local MeleeItems = Items:WaitForChild("melee")
    local ThrowableItems = Items:WaitForChild("throwable")
    local ConsumableItems = Items:WaitForChild("consumable")
    local MiscItems = Items:WaitForChild("misc")

    if GunItems:FindFirstChild(itemName) then return "rbxassetid://109065124754087"
    elseif MeleeItems:FindFirstChild(itemName) then return "rbxassetid://10455604811"
    elseif ThrowableItems:FindFirstChild(itemName) then return "rbxassetid://13492316452"
    elseif ConsumableItems:FindFirstChild(itemName) then return "rbxassetid://17181103870"
    elseif MiscItems:FindFirstChild(itemName) then return "rbxassetid://6966623635"
    else return "" end
end

local function getItemNameByDescription(description)
    local Items = ReplicatedStorage:WaitForChild("Items")
    local GunItems = Items:WaitForChild("gun")
    local MeleeItems = Items:WaitForChild("melee")

    -- Поиск среди оружия
    for _, item in pairs(GunItems:GetChildren()) do
        if item:IsA("Tool") and item:FindFirstChild("Description") and item.Description.Value == description then
            return item.Name
        end
    end
    for _, item in pairs(MeleeItems:GetChildren()) do
        if item:IsA("Tool") and item:FindFirstChild("Description") and item.Description.Value == description then
            return item.Name
        end
    end
    return nil -- Если совпадения нет
end

local function getTargetEquippedItem(target)
    if not target or not target.Character then return "None", nil end
    local character = target.Character
    for _, item in pairs(character:GetChildren()) do
        if item:IsA("Tool") and item.Name:lower() ~= "fists" then
            local description = item:FindFirstChild("Description") and item.Description.Value or nil
            local itemName = description and getItemNameByDescription(description) or item.Name
            return itemName, itemName
        end
    end
    return "None", nil
end

local function getTargetInventory(target)
    if not target then return {} end
    local backpack = target:FindFirstChild("Backpack")
    if not backpack then return {} end
    local _, equippedItemName = getTargetEquippedItem(target)
    local items = {}
    for _, item in pairs(backpack:GetChildren()) do
        if item:IsA("Tool") and item.Name:lower() ~= "fists" and item.Name ~= equippedItemName then
            local description = item:FindFirstChild("Description") and item.Description.Value or nil
            local itemName = description and getItemNameByDescription(description) or item.Name
            table.insert(items, { Name = itemName, Icon = getItemIcon(itemName) })
        end
    end
    return items
end

local function getNearestPlayerToMouse()
    local localPlayer = Core.PlayerData.LocalPlayer
    local localCharacter = localPlayer.Character
    if not localCharacter or not localCharacter:FindFirstChild("HumanoidRootPart") then return nil end
    local localPos = localCharacter.HumanoidRootPart.Position

    local referencePos
    if TargetInventorySettings.CircleMethod.Value == "Middle" then
        local viewportSize = Workspace.CurrentCamera.ViewportSize
        referencePos = Vector2.new(viewportSize.X / 2, viewportSize.Y / 2)
    else
        referencePos = UserInputService:GetMouseLocation()
    end

    local nearestPlayer = nil
    local minDist = TargetInventorySettings.FOV.Value

    for _, player in pairs(Players:GetPlayers()) do
        if player ~= localPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local targetPos = player.Character.HumanoidRootPart.Position
            local screenPos = Workspace.CurrentCamera:WorldToScreenPoint(targetPos)
            local distToReference = (Vector2.new(screenPos.X, screenPos.Y) - referencePos).Magnitude
            local worldDist = (localPos - targetPos).Magnitude

            if distToReference < minDist and (TargetInventorySettings.DistanceLimit == 0 or worldDist <= TargetInventorySettings.DistanceLimit) then
                minDist = distToReference
                nearestPlayer = player
            end
        end
    end
    return nearestPlayer
end

local function isGunEquipped()
    local character = Core.PlayerData.LocalPlayer.Character
    if not character then return false end
    for _, child in pairs(character:GetChildren()) do
        if child:IsA("Tool") then
            local gunItem = game:GetService("ReplicatedStorage"):WaitForChild("Items"):WaitForChild("gun"):FindFirstChild(child.Name)
            return gunItem ~= nil
        end
    end
    return false
end

local function playAppearAnimation()
    if not TargetInventorySettings.AppearAnim then
        invFrame.Size = UDim2.new(0, 220, 0, 150)
        invFrame.BackgroundTransparency = 0.3
        for _, child in pairs(invFrame:GetDescendants()) do
            if child:IsA("TextLabel") or child:IsA("ImageLabel") then
                child.Visible = true
            end
        end
        return
    end

    for _, child in pairs(invFrame:GetDescendants()) do
        if child:IsA("TextLabel") or child:IsA("ImageLabel") then
            child.Visible = false
        end
    end

    invFrame.Size = UDim2.new(0, 220 * 0.5, 0, 150 * 0.5)
    invFrame.BackgroundTransparency = 1

    local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    TweenService:Create(invFrame, tweenInfo, {
        Size = UDim2.new(0, 220, 0, 150),
        BackgroundTransparency = 0.3
    }):Play()

    task.delay(0.5, function()
        for _, child in pairs(invFrame:GetDescendants()) do
            if child:IsA("TextLabel") or child:IsA("ImageLabel") then
                child.Visible = true
            end
        end
    end)
end

local function updateFovCirclePosition()
    if not TargetInventorySettings.Enabled or not TargetInventorySettings.ShowCircle.Value or
       not (TargetInventorySettings.TargetMode == "Mouse" or TargetInventorySettings.TargetMode == "All") then
        fovCircle.Visible = false
        return
    end

    local currentTime = tick()
    if currentTime - TargetInventorySettings.LastFovUpdateTime < TargetInventorySettings.FovUpdateInterval then
        return
    end
    TargetInventorySettings.LastFovUpdateTime = currentTime

    fovCircle.Visible = true
    fovCircle.Size = UDim2.new(0, TargetInventorySettings.FOV.Value, 0, TargetInventorySettings.FOV.Value)
    if TargetInventorySettings.CircleMethod.Value == "Middle" then
        fovCircle.Position = UDim2.new(0.5, -TargetInventorySettings.FOV.Value / 2, 0.5, -TargetInventorySettings.FOV.Value / 2)
    elseif TargetInventorySettings.CircleMethod.Value == "Cursor" then
        local mousePos = UserInputService:GetMouseLocation()
        fovCircle.Position = UDim2.new(0, mousePos.X - TargetInventorySettings.FOV.Value / 2, 0, mousePos.Y - TargetInventorySettings.FOV.Value / 2)
    end

    if TargetInventorySettings.CircleGradient.Value then
        local t = (math.sin(currentTime * 2) + 1) / 2
        fovCircleBorder.Color = Core.GradientColors.Color1.Value:Lerp(Core.GradientColors.Color2.Value, t)
    else
        fovCircleBorder.Color = Color3.fromRGB(255, 255, 255)
    end
end

local function updateTargetInventoryView()
    if not TargetInventorySettings.Enabled then
        invFrame.Visible = false
        return
    end

    local currentTime = tick()
    if currentTime - TargetInventorySettings.LastUpdateTime < TargetInventorySettings.UpdateInterval then
        return
    end
    TargetInventorySettings.LastUpdateTime = currentTime

    local target = nil
    local useMouseTargeting = false

    if TargetInventorySettings.TargetMode == "GunSilent Target" or TargetInventorySettings.TargetMode == "All" then
        target = Core.GunSilentTarget.CurrentTarget
    end
    if TargetInventorySettings.TargetMode == "Mouse" or (TargetInventorySettings.TargetMode == "All" and not target) then
        target = getNearestPlayerToMouse()
        useMouseTargeting = true
    end

    -- Проверка валидности цели
    if target and (not target.Character or not target.Character:FindFirstChild("Humanoid") or target.Character.Humanoid.Health <= 0) then
        target = nil
    end

    local shouldBeVisible = TargetInventorySettings.AlwaysVisible or (target ~= nil)
    if shouldBeVisible and not invFrame.Visible then
        invFrame.Visible = true
        playAppearAnimation()
    elseif not shouldBeVisible then
        invFrame.Visible = false
        return
    end

    -- Пропуск обновления UI, если цель не изменилась
    if TargetInventorySettings.LastTarget == target then
        return
    end
    TargetInventorySettings.LastTarget = target

    if TargetInventorySettings.ShowNick then
        nickLabel.Text = target and target.Name or "No Target"
        nickLabel.Visible = true
    else
        nickLabel.Visible = false
    end

    if not target then
        equippedLabel.Text = "Equipped: No Target"
        equippedIcon.Image = ""
        equippedLabel.Position = UDim2.new(0, 0, 0, 0)
        for _, child in pairs(inventoryFrame:GetChildren()) do
            if child:IsA("Frame") then child:Destroy() end
        end
        local emptyLabel = Instance.new("Frame")
        emptyLabel.Size = UDim2.new(1, 0, 0, 20)
        emptyLabel.BackgroundTransparency = 1
        emptyLabel.Parent = inventoryFrame
        local emptyText = Instance.new("TextLabel")
        emptyText.Size = UDim2.new(1, 0, 1, 0)
        emptyText.BackgroundTransparency = 1
        emptyText.Text = "Items: No Target"
        emptyText.TextColor3 = Color3.fromRGB(255, 255, 255)
        emptyText.TextSize = 14
        emptyText.Font = Enum.Font.Gotham
        emptyText.TextXAlignment = Enum.TextXAlignment.Left
        emptyText.Parent = emptyLabel
        inventoryFrame.CanvasSize = UDim2.new(0, 0, 0, 20)
        return
    end

    local equippedItem, equippedItemName = getTargetEquippedItem(target)
    equippedLabel.Text = "Equipped: " .. equippedItem
    if equippedItemName then
        equippedIcon.Image = getItemIcon(equippedItemName)
        equippedLabel.Position = UDim2.new(0, 25, 0, 0)
    else
        equippedIcon.Image = ""
        equippedLabel.Position = UDim2.new(0, 0, 0, 0)
    end

    for _, child in pairs(inventoryFrame:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end

    local inventory = getTargetInventory(target)
    if #inventory > 0 then
        for i, item in ipairs(inventory) do
            local itemContainer = Instance.new("Frame")
            itemContainer.Size = UDim2.new(1, 0, 0, 20)
            itemContainer.BackgroundTransparency = 1
            itemContainer.LayoutOrder = i
            itemContainer.Parent = inventoryFrame

            local itemIcon = Instance.new("ImageLabel")
            itemIcon.Size = UDim2.new(0, 20, 0, 20)
            itemIcon.Position = UDim2.new(0, 0, 0, 0)
            itemIcon.BackgroundTransparency = 1
            itemIcon.Image = item.Icon
            itemIcon.Parent = itemContainer

            local itemLabel = Instance.new("TextLabel")
            itemLabel.Size = UDim2.new(0, 170, 0, 20)
            itemLabel.Position = UDim2.new(0, 25, 0, 0)
            itemLabel.BackgroundTransparency = 1
            itemLabel.Text = item.Name
            itemLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
            itemLabel.TextSize = 14
            itemLabel.Font = Enum.Font.Gotham
            itemLabel.TextXAlignment = Enum.TextXAlignment.Left
            itemLabel.Parent = itemContainer
        end
        inventoryFrame.CanvasSize = UDim2.new(0, 0, 0, #inventory * 22)
    else
        local emptyLabel = Instance.new("Frame")
        emptyLabel.Size = UDim2.new(1, 0, 0, 20)
        emptyLabel.BackgroundTransparency = 1
        emptyLabel.Parent = inventoryFrame
        local emptyText = Instance.new("TextLabel")
        emptyText.Size = UDim2.new(1, 0, 1, 0)
        emptyText.BackgroundTransparency = 1
        emptyText.Text = "Items: None"
        emptyText.TextColor3 = Color3.fromRGB(255, 255, 255)
        emptyText.TextSize = 14
        emptyText.Font = Enum.Font.Gotham
        emptyText.TextXAlignment = Enum.TextXAlignment.Left
        emptyText.Parent = emptyLabel
        inventoryFrame.CanvasSize = UDim2.new(0, 0, 0, 20)
    end
end

-- [Оставляем перетаскивание для TargetInventory и UI-разделы без изменений]

-- Обновление TargetInventory и TargetHud
RunService.Stepped:Connect(function()
    if TargetHud.Settings.Enabled.Value then
        UpdateTargetHud()
    end
    if TargetInventorySettings.Enabled then
        updateTargetInventoryView()
    end
end)

-- Отдельное обновление позиции круга FOV для плавности
RunService.RenderStepped:Connect(function()
    updateFovCirclePosition()
end)

-- [Оставляем конец файла без изменений]

return TargetInfo