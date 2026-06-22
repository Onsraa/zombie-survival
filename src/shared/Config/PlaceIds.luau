--!strict
--[[
	PlaceIds.luau
	Place IDs for the two-place universe. Fill GAME_PLACE_ID after publishing the Game place
	(Studio: File ▸ Publish to Roblox, then copy the place id from the asset URL). While it's
	0, MatchmakingService skips the teleport (logs a warning) so Studio playtests don't error.
]]

return {
	GAME_PLACE_ID = 0, -- set to the published Game place id to enable lobby → game teleport
}
