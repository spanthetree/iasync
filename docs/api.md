# Game API reference

Where every part of the [SavedVariables file](schema.md) comes from: the ESO
API functions iasync calls, the events that trigger each scan, and the
base-UI objects it borrows. iasync reads; none of these calls change game
state.

Function signatures and return values are documented in
`ESOUIDocumentation.txt` on the `live` branch of
[esoui/esoui](https://github.com/esoui/esoui) (the `master` branch is out of
date). iasync targets API version `101051`. Calls that can fail are wrapped in
`pcall`, and globals added in later patches are checked before use, so a
missing function leaves its field empty instead of stopping the scan.

## When each scan runs

| Event | Scan | Delay |
|---|---|---|
| `EVENT_PLAYER_ACTIVATED` (login, `/reloadui`, zone change) | Interface colours | none |
| | Character, build, Armory builds, skill names, character details | 2 s |
| | House chests | 3 s |
| | Activities | 4 s |
| | Achievements | 5 s |
| | Scribing, antiquities, Champion catalogue | 6 s |
| | Set collections | 7 s |
| | Collectibles | 9 s |
| `EVENT_OPEN_BANK` | Bank, ESO Plus bank, craft bag | none |
| `EVENT_GUILD_BANK_ITEMS_READY` | The selected guild bank | none |
| `EVENT_GUILD_BANK_ITEM_ADDED`, `_ITEM_REMOVED`, `_UPDATED_QUANTITY` | The selected guild bank | 0.5 s after the last one |
| `EVENT_INVENTORY_SINGLE_SLOT_UPDATE` | The changed slot (character, bank, craft bag or house chest) | none |
| `EVENT_ARMORY_BUILD_SAVE_RESPONSE`, `_RESTORE_RESPONSE`, `_UPDATED` | Armory builds and their skill names | none |
| `EVENT_ACHIEVEMENT_AWARDED` | That achievement | none |
| `EVENT_ACHIEVEMENTS_UPDATED` | All achievements | none |
| `EVENT_TIMED_ACTIVITIES_UPDATED`, `EVENT_TIMED_ACTIVITY_PROGRESS_UPDATED`, `EVENT_PROMOTIONAL_EVENTS_CAMPAIGNS_UPDATED`, `_ACTIVITY_PROGRESS_UPDATED`, `_REWARDS_CLAIMED` | Activities | 2 s after the last one |

The delays give the game time to load data that isn't ready when
`EVENT_PLAYER_ACTIVATED` fires: house chest sizes read 0 at first, and the set
collection manager fills in late. `/script iasync_scan()` runs every scan at
once.

## Items

Every stored item (`slotData`) is read the same way, from its bag and slot.

| Field | Functions |
|---|---|
| `name`, `link` | `GetItemName`, `GetItemLink` |
| `traitType`, `traitName` | `GetItemTrait` (names from a table in `iasync.lua`) |
| `enchantName` | `GetItemLinkEnchantInfo` |
| `setId`, `setName` | `GetItemLinkSetInfo` |
| `quality` | `GetItemDisplayQuality` |
| `filterType` | `GetItemFilterTypeInfo` |
| `icon`, `qty` | `GetItemInfo`, falling back to `GetItemLinkIcon` |
| `armorType`, `weaponType` | `GetItemLinkArmorType`, `GetItemLinkWeaponType` |

## Character (`chars[id]`)

| Data | Functions |
|---|---|
| Identity | `GetCurrentCharacterId`, `GetUnitName`, `GetUnitRace`, `GetUnitClass`, `GetUnitAlliance`, `GetAllianceName`, `GetUnitGender`, `GetDisplayName` |
| Bags (`bags`) | `GetBagSize` over `BAG_WORN` and `BAG_BACKPACK` |
| Gold, AP, Tel Var, writs | `GetCurrencyAmount` |
| Details | `GetUnitLevel`, `GetUnitChampionPoints`, `GetUnitTitle`, `GetUnitZone`, `GetUnitZoneIndex`, `GetZoneId`, `GetRidingStats`, `GetUnitAvARank`, `GetAvARankName` |
| Guilds | `GetNumGuilds`, `GetGuildId`, `GetGuildName`, `GetPlayerGuildMemberIndex`, `GetGuildMemberInfo`, `GetGuildRankCustomName` |
| Currencies | `IsCurrencyValid`, `GetCurrencyName`, `GetCurrencyKeyboardIcon`, `GetCurrencyPlayerStoredLocation`, `GetCurrencyAmount` |
| Trait research (`research`) | `GetNumSmithingResearchLines`, `GetSmithingResearchLineInfo`, `GetSmithingResearchLineTraitInfo`, `GetSmithingResearchLineTraitTimes` |
| Motifs (`motifs`) | `GetNumLoreCategories`, `GetLoreCategoryInfo`, `GetLoreCollectionInfo`, `GetLoreBookInfo` (the Lore Library's "Crafting Motifs" category) |
| Recipes (`recipes`) | `GetNumRecipeLists`, `GetRecipeListInfo`, `GetRecipeInfo` |
| Scribing (`scribing`) | `IsScribingEnabled`, `GetNumCraftedAbilities`, `GetCraftedAbilityIdAtIndex`, `GetCraftedAbilityDisplayName`, `GetCraftedAbilityIcon`, `IsCraftedAbilityUnlocked`, `IsCraftedAbilityScribed`, `GetAbilityIdForCraftedAbilityId`, `GetNumScriptsInSlotForCraftedAbility`, `GetScriptIdAtSlotIndexForCraftedAbility`, `GetCraftedAbilityScriptDisplayName`, `IsCraftedAbilityScriptUnlocked` |

## Build (`build_*`)

| Data | Functions |
|---|---|
| Bars (`build_bars`) | `GetSlotBoundId`, `GetSlotType`, `GetAbilityIdForCraftedAbilityId` (scribed skills to their base ability) |
| Attributes (`build_attributes`) | `GetAttributeSpentPoints` |
| Max resources (`build_pools`) | `GetPlayerStat` with `STAT_BONUS_OPTION_APPLY_BONUS` |
| Mundus (`build_mundus`, `mundusDescriptions`) | `GetNumBuffs`, `GetUnitBuffInfo` (a buff whose icon path contains "mundus"), `GetAbilityDescription` |
| Champion (`build_cp`) | `GetPlayerChampionPointsEarned`, `GetSlotBoundId` with `HOTBAR_CATEGORY_CHAMPION` |
| Skill names and icons (`abilityNames`, `abilityIcons`) | `GetAbilityName`, `GetAbilityIcon` |
| Star names (`cpNames`, `cpDescriptions`) | `GetChampionSkillName`, `GetNumPointsSpentOnChampionSkill`, `GetChampionSkillDescription` |

Skill names also cover the logged-in character's saved
[Wizard's Wardrobe](https://www.esoui.com/downloads/info3170-WizardsWardrobe.html)
setups, read from its `WizardsWardrobeSV` table when that addon is installed.

## Armory builds (`chars[id].armoryBuilds`)

| Data | Functions |
|---|---|
| Builds | `GetNumUnlockedArmoryBuilds` |
| Name, icon | `GetArmoryBuildName`, `GetArmoryBuildIconIndex` (path from `ZO_ARMORY_BUILD_ICON_TEXTURE_FORMATTER`) |
| Gear | `GetArmoryBuildEquipSlotInfo` for each `BAG_WORN` slot, then the item from its current bag and slot. A missing item reports a placeholder location (`BAG_BACKPACK`, 0) that is never read; `lastKnown` comes from the previous scan |
| Bars, Champion stars | `GetArmoryBuildSlotBoundId`, `GetEffectiveAbilityIdForAbilityOnHotbarForArmoryBuild` |
| Champion points | `GetNumChampionDisciplines`, `GetChampionDisciplineId`, `GetChampionDisciplineName`, `GetArmoryBuildChampionSpentPointsByDiscipline` |
| Attributes, skill points | `GetArmoryBuildAttributeSpentPoints`, `GetArmoryBuildSkillsTotalSpentPoints` |
| Mundus | `GetArmoryBuildPrimaryMundusStone`, `GetArmoryBuildSecondaryMundusStone`, `GetString("SI_MUNDUSSTONE", stone)` |
| Curse, outfit | `GetArmoryBuildCurseType`, `GetArmoryBuildEquippedOutfitIndex`, `ZO_OUTFIT_MANAGER:GetOutfitManipulator(...):GetOutfitName()` |

`GetArmoryBuildSlotBoundId` returns 0 until the client has visited an Armory
station; the other functions work anywhere.

## Storage

| Data | Functions |
|---|---|
| Bank (`bank`) | `GetBagSize` over `BAG_BANK` and `BAG_SUBSCRIBER_BANK`; `GetNextVirtualBagSlotId` for the craft bag (`BAG_VIRTUAL`); `GetCurrencyAmount` at `CURRENCY_LOCATION_BANK` |
| Houses (`houses`) | `GetCurrentZoneHouseId`, `IsOwnerOfCurrentHouse`, `GetCollectibleIdForHouse`, `GetCollectibleName`, `GetBagSize` from `BAG_HOUSE_BANK_ONE` |
| Guild banks (`guildBanks`) | `GetSelectedGuildBankId`, `GetGuildName`, `ZO_GetNextBagSlotIndex` over `BAG_GUILDBANK` |

## Achievements (`achievements`, `chars[id].achievements`)

| Data | Functions |
|---|---|
| Categories | `GetNumAchievementCategories`, `GetAchievementCategoryInfo`, `GetAchievementSubCategoryInfo`, `GetAchievementCategoryKeyboardIcons` |
| Achievements | `GetAchievementId`, `GetAchievementInfo`, `GetAchievementPersistenceLevel` (account-wide or per character), `GetAchievementTimestamp`, `GetCategoryInfoFromAchievementId` |
| Criteria | `GetAchievementNumCriteria`, `GetAchievementCriterion` |
| Lines | `GetFirstAchievementInLine`, `GetPreviousAchievementInLine`, `GetNextAchievementInLine` |
| Who earned it | `GetCharIdForCompletedAchievement`, `GetCharacterNameById` |
| Rewards | `GetAchievementRewardTitle`, `GetAchievementRewardDye`, `GetAchievementRewardCollectible`, `GetAchievementRewardItem`, `GetAchievementRewardTributeCardUpgradeInfo`, `GetTributePatronDockCardInfoByIndex`, `GetTributeCardName`, `GetTributePatronName` |

## Collections

| Data | Functions |
|---|---|
| Set collections (`stickerbook`) | `ITEM_SET_COLLECTIONS_DATA_MANAGER` (categories, sets, reconstruction cost), `GetNumItemSetCollectionPieces`, `GetNumItemSetCollectionSlotsUnlocked`, `GetItemSetCollectionPieceInfo`, `IsItemSetCollectionSlotUnlocked`, `GetItemSetName`, `GetItemSetCollectionPieceItemLink`, `GetItemLinkName`, `GetItemLinkIcon`, `GetItemLinkDisplayQuality`, `GetEquipmentFilterTypeForItemSetCollectionSlot` |
| Collectibles (`collectibles`) | `GetNumCollectibleCategories`, `GetCollectibleCategoryInfo`, `GetCollectibleCategoryKeyboardIcons`, `GetCollectibleCategorySpecialization`, `GetCollectibleSubCategoryInfo`, `GetCollectibleId`, `GetCollectibleInfo` |
| Tribute patrons (`collectibles.patrons`) | `GetNumTributePatrons`, `GetTributePatronIdAtIndex`, `GetTributePatronName`, `GetTributePatronCollectibleId`, `GetTributePatronLargeIcon`, `GetTributePatronSmallIcon`, `GetTributePatronSuitIcon`, `GetTributePatronRarity`, `IsTributePatronNeutral`, `GetTributePatronCategoryId`, `GetTributePatronCategoryName`, `GetTributePatronCategoryKeyboardIcons`, `GetTributePatronCategorySortOrder` |
| Antiquities (`antiquities`) | `GetNextAntiquityId`, `GetAntiquityName`, `GetAntiquityIcon`, `GetAntiquityQuality`, `GetAntiquitySetId`, `GetAntiquitySetName`, `GetAntiquityZoneId`, `GetZoneNameById`, `IsAntiquityRepeatable`, `GetNumAntiquitiesRecovered`, `GetNumAntiquityLoreEntries`, `GetNumAntiquityLoreEntriesAcquired`, `DoesAntiquityHaveLead`, `GetAntiquityLeadTimeRemainingSeconds` |
| Champion catalogue (top-level `cpNames`, `cpDescriptions`) | `GetNumChampionDisciplines`, `GetNumChampionDisciplineSkills`, `GetChampionSkillId`, `GetChampionSkillName`, `GetChampionSkillMaxPoints`, `GetChampionSkillDescription` |

## Activities (`activities`)

| Data | Functions |
|---|---|
| Endeavors and Tome challenges (`timed`, `limits`) | `IsTimedActivitySystemAvailable`, `GetNumTimedActivities`, `GetTimedActivityId`, `GetTimedActivityName`, `GetTimedActivityDescription`, `GetTimedActivityType`, `GetTimedActivityDifficulty`, `GetTimedActivityProgress`, `GetTimedActivityMaxProgress`, `GetTimedActivityEndTimeS`, `GetTimedActivityCurrencyRewardInfo`, `GetTimedActivityNumTimesClaimed`, `GetTimedActivityTotalNumTimesClaimable`, `GetTimedActivityTypeResetTimeS` |
| Golden Pursuits (`campaigns`) | `IsPromotionalEventSystemLocked`, `GetNumActivePromotionalEventCampaigns`, `GetActivePromotionalEventCampaignKey`, `ShouldPromotionalEventCampaignBeVisible`, `GetPromotionalEventCampaignInfo`, `GetPromotionalEventCampaignDisplayName`, `GetPromotionalEventCampaignDescription`, `GetPromotionalEventCampaignProgress`, `GetSecondsRemainingInPromotionalEventCampaign`, `GetPromotionalEventCampaignActivityInfo`, `GetPromotionalEventCampaignActivityProgress`, `GetPromotionalEventCampaignMilestoneInfo`, `GetPromotionalEventCampaignMilestoneRewardFlags`, `BitAnd` |
| Tamriel Tome (`tome`) | `IsTamrielTomesEnabled`, `GetActiveTamrielTomeSeasonDefId`, `GetActiveTamrielTomeSeasonEndTimeS`, `HasTamrielTomeProductType`, `GetTamrielTomesRewardInfo`, `GetNumReferenceTracksForType`, `GetActiveReferenceTrackIdsForRewardTrackType`, `GetReferenceTrackIndex`, `GetInfoForRewardTrack`, `GetRewardTrackDisplayName`, `GetTotalNumTiersForRewardTrack`, `GetTotalProgressAtRewardTrackTier`, `GetNumRewardsAtRewardTrackTier`, `GetRewardTrackRewardClaimedState`, `HasAccessToRewardTrackComponent`, `REWARDS_MANAGER:GetInfoForReward` |

## Interface colours (`uiColors`)

`GetInterfaceColor`, for the text and XP bar colours ESO Armory uses to match
the game.

## Base-UI objects

These are not in `ESOUIDocumentation.txt`. They come from ZeniMax's own UI
code, also in [esoui/esoui](https://github.com/esoui/esoui), and can change
without notice.

| Object | Used for |
|---|---|
| `ITEM_SET_COLLECTIONS_DATA_MANAGER` | Set collection categories and sets |
| `REWARDS_MANAGER` | Tamriel Tome reward names and icons |
| `ZO_OUTFIT_MANAGER` | Armory outfit names |
| `ZO_ARMORY_BUILD_ICON_TEXTURE_FORMATTER` | Armory build icon paths |
| `ZO_GetNextBagSlotIndex` | Walking guild bank slots |
| `zo_callLater` | Delayed scans |
