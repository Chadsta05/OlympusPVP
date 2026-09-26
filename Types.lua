--[[
  OlympusPVP type declarations (LuaCATS). No runtime behavior.
]]

---@class OlympusPVPSettings
---@field enabled boolean
---@field alertCooldownMs number
---@field raidWarningEnabled boolean
---@field soundEnabled boolean
---@field chatEnabled boolean
---@field pvpModeEnabled boolean
---@field gankNames string[]

---@class PartialOlympusPVPSettings
---@field enabled? boolean
---@field alertCooldownMs? number
---@field raidWarningEnabled? boolean
---@field soundEnabled? boolean
---@field chatEnabled? boolean
---@field pvpModeEnabled? boolean
---@field gankNames? string[]

---@class OlympusPVPSettingsStore
---@field GetSettings fun(): OlympusPVPSettings
---@field UpdateSettings fun(changes: PartialOlympusPVPSettings): OlympusPVPSettings
---@field ResetSettings fun(): OlympusPVPSettings

---@class OlympusPVPMapPosition
---@field x number
---@field y number
---@field mapId? string

---@class OlympusPVPDetection
---@field name string
---@field zone string
---@field source string
---@field time number
---@field x? number
---@field y? number
---@field mapId? string

---@class OlympusPVPUnitInfo
---@field className? string
---@field level? number
---@field portraitUrl? string
---@field healthPercent? number
---@field powerPercent? number
---@field powerType? string

---@class OlympusPVPCombatant
---@field name string
---@field className? string
---@field classColor string
---@field level? number
---@field portraitUrl? string
---@field unit? string
---@field healthPercent number
---@field powerPercent number
---@field powerType string
---@field updatedAt number

---@class OlympusPVPGankPointer
---@field name string
---@field needleDegrees number
---@field x? number
---@field y? number
---@field zone string

---@class OlympusPVPEventPayload
---@field unit? string
---@field sourceName? string
---@field destinationName? string
---@field sourceIsSelf? boolean
---@field destinationIsSelf? boolean
---@field isDamage? boolean
---@field subevent? string

---@alias OlympusPVPEventHandler fun(event: string, payload?: OlympusPVPEventPayload)

---@class OlympusPVPDependencies
---@field getZoneText fun(): string?
---@field getSubZoneText fun(): string?
---@field getPlayerPosition fun(): OlympusPVPMapPosition?
---@field unitExists fun(unit: string): boolean
---@field unitName fun(unit: string): string?
---@field showRaidWarning fun(message: string)
---@field printToChat fun(message: string)
---@field playRaidWarningSound fun()
---@field requestTarget fun(name: string)
---@field registerEvent fun(event: string, handler: OlympusPVPEventHandler)
---@field now fun(): number
---@field getSettings fun(): OlympusPVPSettings
---@field getPlayerName? fun(): string?
---@field unitIsPlayer? fun(unit: string): boolean
---@field unitTargetsPlayer? fun(unit: string): boolean
---@field inspectPvpUnit? fun(unit: string): OlympusPVPUnitInfo?
---@field inspectPvpName? fun(name: string): OlympusPVPUnitInfo?
---@field queuePvpTarget? fun(name: string)
---@field getUnitPosition? fun(unit: string): OlympusPVPMapPosition?
---@field getPlayerFacingDegrees? fun(): number?
---@field getInstanceType? fun(): string?

---@class OlympusPVPApi
---@field Start fun()
---@field HandleEvent OlympusPVPEventHandler
---@field NotePvpPlayer fun(name: string, unit?: string)
---@field GetPvpCombatants fun(): OlympusPVPCombatant[]
---@field ClearPvpCombatants fun()
---@field DismissPvpCombatant fun(name: string)
---@field IsPvpCombatant fun(name?: string): boolean
---@field IsGankTarget fun(name?: string): boolean
---@field GetLastGankSighting fun(): OlympusPVPDetection?
---@field GetGankPointer fun(): OlympusPVPGankPointer?
---@field CheckUnit fun(unit: string, source: string)
---@field CheckCombatLog fun(event: OlympusPVPEventPayload)

---@class OlympusPVPNamespace
---@field TypeGuards table
---@field Settings table
---@field ClassColors table
---@field PvpLayout table
---@field GankPointer table
---@field Core table
---@field AddonController table
---@field SettingsPanel table
---@field WowBridge table
---@field RaidFrames table
---@field settingsStore? OlympusPVPSettingsStore
---@field scanner? OlympusPVPApi
---@field settingsPanel? table
---@field controller? table
