Scriptname WheelMenuWidget extends Quest

Keyword Property AlcoholKeyword Auto
Keyword Property ChemKeyword Auto
Keyword Property DrinkKeyword Auto
Keyword Property FoodKeyword Auto
Keyword Property GrenadeExplosiveKeyword Auto
Keyword Property GrenadeGrenadeKeyword Auto
Keyword Property GrenadeMineKeyword Auto
Keyword Property GrenadeThrownKeyword Auto
Keyword Property Melee1HKeyword Auto
Keyword Property Melee2HKeyword Auto
Keyword Property NukaKeyword Auto
Int Property SlowTimeMode Auto
Spell Property SlowTimeSpell Auto
Keyword Property StimpackKeyword Auto
Keyword Property WaterKeyword Auto


String WheelMenuName = "F4WheelMenu" const

Struct Item
    int Id
    string Name
    string Description
    int Count
    bool Equipped
    string Category
EndStruct

; Easier and faster to track them separately
Item[] weaponInventoryItems
Item[] ingestibleInventoryItems

; Return default sorting category for the form
string Function GetItemCategory(Form item)
    if (item is Weapon)
        Weapon itemW = item as Weapon
        If (itemW.HasKeyword(Melee1HKeyword) || itemW.HasKeyword(Melee2HKeyword))
            return MELEE
        ElseIf (itemW.HasKeyword(GrenadeExplosiveKeyword) || itemW.HasKeyword(GrenadeGrenadeKeyword) || itemW.HasKeyword(GrenadeMineKeyword) || itemW.HasKeyword(GrenadeThrownKeyword))
            return EXPLOSIVE
        Else
            return RANGED
        Endif
    Else
        if (item.HasKeyword(ChemKeyword) || item.HasKeyword(StimpackKeyword))
            return CHEMS
        ElseIf ((item.HasKeyword(WaterKeyword) || item.HasKeyword(DrinkKeyword) || item.HasKeyword(NukaKeyword)) && !item.HasKeyword(AlcoholKeyword))
            return DRINK
        ElseIf (item.HasKeyword(AlcoholKeyword))
            return ALCOHOL
        ElseIf (item.HasKeyword(FoodKeyword))
            return FOOD
        Else
            return INGESTIBLE
        EndIf
    Endif
EndFunction

; Init inventory items. Run on game/quest initialization
Function InitInventoryItems(Actor player)
    Debug.Trace("WheelMenu: Initializing player inventory")
    weaponInventoryItems = new Item[0]
    ingestibleInventoryItems = new Item[0]
    ; Getting inventory items is fast
    ; Iterating through items is fast
    ; Calculating count of items in inventory is SLOW
    ; Checking isEquipped() for each weapon item is SLOW
    Form[] items = player.GetInventoryItems()
    int currentItem = 0
    While (currentItem < items.Length)
        Form item = items[currentItem]
        If ((item is Weapon) || (item is Potion))
            Item invItem = new Item
            invItem.Id = item.GetFormID()
            invItem.Name = item.GetName()
            invItem.Description = ""
            ; Only once when initialization, later we'll track them though onItemAdded/Removed/Equipped
            invItem.Count = player.GetItemCount(item)
            invItem.Equipped = false

            If (item is Weapon)
                weaponInventoryItems.Add(invItem)
            Else
                ingestibleInventoryItems.Add(invItem)
            Endif
        Endif
        currentItem += 1
    EndWhile
    Debug.Trace("WheelMenu: Initial items were initialized, weapon count: " + weaponInventoryItems.Length + ", ingestible count: " + ingestibleInventoryItems.Length)
EndFunction

Function RemoveItem(Form item, int count = 1)
    Item[] arr
    If (item is Weapon)
        arr = weaponInventoryItems
    ElseIf (item is Potion)
        arr = ingestibleInventoryItems
    Else
        Return
    Endif
    int itemIndex = arr.FindStruct("Id", item.GetFormID())
    If (itemIndex < 0)
        Return
    Endif
    Item invItem = arr[itemIndex]
    invItem.Count -= count;
    ; last consumed/removed , remove
    If (invItem.Count <= 0)
        arr.Remove(itemIndex)
    Endif
EndFunction

Function AddItem(Form item, int count = 1)
    Item[] arr
    If (item is Weapon)
        arr = weaponInventoryItems
    ElseIf (item is Potion)
        arr = ingestibleInventoryItems
    Else
        Return
    Endif
    int id = item.GetFormID()
    int currentItemIndex = arr.FindStruct("Id", id)
    If (currentItemIndex >= 0)
        ; exist, just increase count
        Item invItem = arr[currentItemIndex]
        invItem.Count += count
    Else
        ; new item added
        Item invItem = new Item
        invItem.Id = id
        invItem.Name = item.GetName()
        invItem.Description = ""
        invItem.Equipped = false
        invItem.Count = count
        invItem.Category = GetItemCategory(item)
        arr.Add(invItem)
    Endif
EndFunction

Function ToggleMenu()
    Actor player = Game.GetPlayer()
    If (!UI.IsMenuRegistered(WheelMenuName))
        Return
    EndIf
    If (UI.IsMenuOpen(WheelMenuName))
        player.DispelSpell(SlowTimeSpell)
        UI.CloseMenu(WheelMenuName)
    Else
        Debug.Trace("WheelMenu: SlowTimeMode: " + SlowTimeMode)
        if (SlowTimeMode == 0 || (SlowTimeMode == 1 && player.IsInCombat()))
            player.DoCombatSpellApply(SlowTimeSpell, player)
        EndIf
        UI.OpenMenu(WheelMenuName)
    EndIf
EndFunction

Function RegisterMenu()
    If (!UI.IsMenuRegistered(WheelMenuName))
        UI:MenuData data = new UI:MenuData
        ; data.MenuFlags = ShowCursor|DoNotPreventGameSave|EnableMenuControl
        data.MenuFlags = 2060
        UI.RegisterCustomMenu(WheelMenuName, "WheelMenu", "root1", data)
    EndIf
EndFunction

Function RegisterForCustomEvents(Actor player)
    ; RegisterForRemoteEvent(player, "onItemEquipped")
    RegisterForRemoteEvent(player, "onItemAdded")
    RegisterForRemoteEvent(player, "onItemRemoved")
    ; Todo: investigate possibility of applying only to specific keywords only
    AddInventoryEventFilter(none)
    RegisterForKey(71); g
    RegisterForExternalEvent("WheelMenuInit", "onMenuInit")
    RegisterForExternalEvent("WheelMenuSelect", "onMenuSelect")
EndFunction

Event OnQuestInit()
    Actor player = Game.GetPlayer()
    RegisterForRemoteEvent(player, "OnPlayerLoadGame")
    RegisterMenu()
    RegisterForCustomEvents(player)
    InitInventoryItems(player)
EndEvent

Event Actor.OnPlayerLoadGame(Actor akSender)
    Actor player = Game.GetPlayer()
    RegisterMenu()
    RegisterForCustomEvents(player)
    InitInventoryItems(player)
EndEvent

Event ObjectReference.OnItemAdded(ObjectReference akSender, Form akBaseItem, int aiItemCount, ObjectReference akItemReference, ObjectReference akSourceContainer)
    If (!(akBaseItem is Weapon) && !(akBaseItem is Potion))
        Return
    EndIf
    AddItem(akBaseItem, aiItemCount)
EndEvent

Event ObjectReference.OnItemRemoved(ObjectReference akSender, Form akBaseItem, int aiItemCount, ObjectReference akItemReference, ObjectReference akDestContainer)
    If (!(akBaseItem is Weapon) && !(akBaseItem is Potion))
        Return
    EndIf
    RemoveItem(akBaseItem, aiItemCount)
EndEvent

Event OnKeyDown(int aiKeyCode)
    If (aiKeyCode == 71)
        ToggleMenu()
    Endif
EndEvent


;; Wheel menu is ready
Function onMenuInit()
    Debug.Trace("WheelMenu: Menu initialized")
    If (UI.IsMenuOpen(WheelMenuName))
        UI.Set(WheelMenuName, "root1.inventoryItems", Utility.VarArrayToVar(ingestibleInventoryItems as Var[]))
        UI.Set(WheelMenuName, "root1.inventoryItems", Utility.VarArrayToVar(weaponInventoryItems as Var[]))

        ; Set equipped status
        Actor player = Game.GetPlayer()
        ; slot 0 - guns, melee (1h/2h)
        ; slot 2 - grenades/mines
        Weapon equippedWeap = player.GetEquippedWeapon(0)
        Weapon equippedGrenade = player.GetEquippedWeapon(2)

        If (equippedGrenade)
            int id = equippedGrenade.GetFormID()
            Debug.Trace("WheelMenu: Detected equipped grenade/mine id: " + id)
            UI.Set(WheelMenuName, "root1.equippedItemId", id)
        Endif
        If (equippedWeap)
            int id = equippedWeap.GetFormID()
            Debug.Trace("WheelMenu: Detected equipped weapon id: " + id)
            UI.Set(WheelMenuName, "root1.equippedItemId", id)
        Endif
    Endif
EndFunction

;; Selected item
Function onMenuSelect(int id)
    Debug.Trace("WheelMenu: Selected id: " + id)
    Actor player = Game.GetPlayer()
    Form item = Game.GetForm(id)
    If (item)
        Debug.Trace("WheelMenu: Equipping item: " + item.GetFormID())
        player.EquipItem(item, false, true)
    EndIf
    If (Ui.IsMenuOpen(WheelMenuName))
        player.DispelSpell(SlowTimeSpell)
        UI.CloseMenu(WheelMenuName)
    Endif
EndFunction


Group ItemCategories
    string Property MELEE = "MeleeWeapons" AutoReadOnly
    string Property RANGED = "RangedWeapons" AutoReadOnly
    string Property EXPLOSIVE = "Explosives" AutoReadOnly
    string Property FOOD = "Food" AutoReadOnly
    string Property ALCOHOL = "Alcohol" AutoReadOnly
    string Property DRINK = "Drink" AutoReadOnly
    string Property CHEMS = "Chems" AutoReadOnly
    string Property INGESTIBLE = "Ingestible" AutoReadOnly
EndGroup

Group MenuFlags
    int Property FlagNone = 0x0 AutoReadOnly
    int Property PauseGame = 0x01 AutoReadOnly
    int Property DoNotDeleteOnClose = 0x02 AutoReadOnly
    int Property ShowCursor = 0x04 AutoReadOnly
    int Property EnableMenuControl = 0x08 AutoReadOnly
    int Property ShaderdWorld = 0x20 AutoReadOnly
    int Property Open = 0x40 AutoReadOnly
	int Property DoNotPreventGameSave = 0x800 AutoReadOnly
	int Property ApplyDropDownFilter = 0x8000 AutoReadOnly
	int Property BlurBackground = 0x400000 AutoReadOnly
EndGroup