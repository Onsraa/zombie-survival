--!strict
--[[
	tests/run.luau
	Lune test runner for PURE logic modules (no Roblox APIs). Run with: `lune run tests/run`.
	Pure config modules are unit-testable here, fast and deterministic.
]]

local ZombieConfig = require("../src/shared/Config/ZombieConfig")
local WeaponConfig = require("../src/shared/Config/WeaponConfig")

local passed = 0
local failed = 0

local function check(name: string, condition: boolean, detail: string?)
	if condition then
		passed += 1
		print(`  PASS: {name}`)
	else
		failed += 1
		print(`  FAIL: {name}{if detail then " — " .. detail else ""}`)
	end
end

local function eq(name: string, actual: number, expected: number)
	check(name, actual == expected, `expected {expected}, got {actual}`)
end

print("ZombieConfig.getHealth")
eq("R1 = 150 (base)", ZombieConfig.getHealth(1), 150)
eq("R9 = 950 (end of flat phase)", ZombieConfig.getHealth(9), 950)
eq("R10 = 1045 (+10% compounding starts)", ZombieConfig.getHealth(10), 1045)
eq("R20 = 2710 (compounded)", ZombieConfig.getHealth(20), 2710)
check("health is monotonic R1..R30", (function()
	for r = 2, 30 do
		if ZombieConfig.getHealth(r) <= ZombieConfig.getHealth(r - 1) then
			return false
		end
	end
	return true
end)())

print("ZombieConfig.getWalkSpeed (tiers)")
eq("R1 walk", ZombieConfig.getWalkSpeed(1), 8)
eq("R4 trot", ZombieConfig.getWalkSpeed(4), 12)
eq("R7 sprint", ZombieConfig.getWalkSpeed(7), 16)
eq("R10 super-sprint", ZombieConfig.getWalkSpeed(10), 22)

print("ZombieConfig.getSpawnCount (round + player scaling)")
eq("R1 / 1p = 8", ZombieConfig.getSpawnCount(1, 1), 8)
eq("R1 / 4p = 20", ZombieConfig.getSpawnCount(1, 4), 20)
eq("R10 / 1p = 26", ZombieConfig.getSpawnCount(10, 1), 26)
check("cap is 24", ZombieConfig.MAX_CONCURRENT == 24)

print("WeaponConfig")
check("starting weapon = pistol", WeaponConfig.STARTING_WEAPON == "pistol")
check("pistol has no wall-buy cost", WeaponConfig.get("pistol") ~= nil and WeaponConfig.get("pistol").wallBuyCost == nil)
check("rifle is purchasable + auto", (function()
	local r = WeaponConfig.get("rifle")
	return r ~= nil and r.wallBuyCost ~= nil and r.auto == true
end)())

print(`\nResults: {passed} passed, {failed} failed`)
if failed > 0 then
	error(`{failed} test(s) failed`)
end
