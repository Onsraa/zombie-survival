--!strict
--[[
	ZombieAnimations.luau
	AnimationIds for the zombie rig, keyed by the asset name used in ZombieController's
	ANIM_NAMES. PURE (no Roblox APIs).

	WHY THIS EXISTS: the clips under ReplicatedStorage.Assets.Animations are authored as
	KeyframeSequences, which only play in Studio (preview) — never in a published game.
	To make them fire at runtime they must be uploaded to real Animation assets.

	HOW TO FILL (one-time, per clip):
	  1. In Studio, select ReplicatedStorage.Assets.Models.Zombie and open the Animation Editor.
	  2. Load the matching KeyframeSequence from Assets.Animations.
	  3. Export (publishes to your account) → copy the returned id.
	  4. Paste it below as "rbxassetid://<number>".

	Any entry left as "" falls back to the Studio-only KeyframeSequence preview
	(ZombieController resolves it), so dev preview keeps working until you upload.
]]

local ZombieAnimations: { [string]: string } = {
	ZombieWalk = "rbxassetid://74301920399361", -- arms-forward walk (the main one)
	ZombieRun = "rbxassetid://114097433763257",
	ZombieCrawl = "rbxassetid://116854462238266",
	ZombieAttackStanding = "rbxassetid://87173576296276",
	ZombieAttackCrawling = "rbxassetid://118970271924953",
	ZombieRemovePlanks = "rbxassetid://93581905577093",
	ZombieDeath = "", -- collapse-on-floor; author + upload for an explicit death animation
}

return ZombieAnimations
