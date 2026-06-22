--!strict
--[[
	tests/run.luau
	Lune test runner for PURE logic modules (no Roblox APIs). Run with: `lune run tests/run`.
]]

local ZombieConfig = require("../src/shared/Config/ZombieConfig")
local Ballistics = require("../src/shared/Weapons/Ballistics")

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

local function near(name: string, actual: number, expected: number)
	check(name, math.abs(actual - expected) < 1e-6, `expected ~{expected}, got {actual}`)
end

print("ZombieConfig.getHealth")
eq("R1 = 150 (base)", ZombieConfig.getHealth(1), 150)
eq("R9 = 950 (end of flat phase)", ZombieConfig.getHealth(9), 950)
eq("R10 = 1045 (+10% compounding starts)", ZombieConfig.getHealth(10), 1045)
eq("R20 = 2710 (compounded)", ZombieConfig.getHealth(20), 2710)

print("ZombieConfig.getWalkSpeed / getSpawnCount")
eq("R1 walk", ZombieConfig.getWalkSpeed(1), 8)
eq("R10 super-sprint", ZombieConfig.getWalkSpeed(10), 22)
eq("R1 / 1p spawn = 8", ZombieConfig.getSpawnCount(1, 1), 8)
eq("R1 / 4p spawn = 20", ZombieConfig.getSpawnCount(1, 4), 20)

print("Ballistics.rpmToCooldown")
near("600 rpm = 0.1s", Ballistics.rpmToCooldown(600), 0.1)
near("300 rpm = 0.2s", Ballistics.rpmToCooldown(300), 0.2)
eq("0 rpm = 0", Ballistics.rpmToCooldown(0), 0)

print("Ballistics spread bloom / recover")
local spread = { base = 1.0, max = 4.0, bloomPerShot = 0.8, recover = 6 }
near("bloom from base = 1.8", Ballistics.bloomSpread(1.0, spread), 1.8)
eq("bloom clamps to max", Ballistics.bloomSpread(3.6, spread), 4.0)
near("bloom from below base uses base", Ballistics.bloomSpread(0.5, spread), 1.8)
eq("recover floors at base", Ballistics.recoverSpread(4.0, spread, 1.0), 1.0)
near("recover partial", Ballistics.recoverSpread(4.0, spread, 0.1), 3.4)

print("Ballistics.pierceDamage")
eq("pierce 0 = full", Ballistics.pierceDamage(50, 0.85, 0), 50)
near("pierce 1 = x0.85", Ballistics.pierceDamage(50, 0.85, 1), 42.5)
near("pierce 2 = x0.85^2", Ballistics.pierceDamage(50, 0.85, 2), 36.125)

print("Party model")
local Party = require("../src/shared/Party")
local party = Party.new(1, 100, "Alice")
check("new -> 1 member", Party.count(party) == 1)
check("leader = creator", party.leaderUserId == 100)
check("not all ready (leader unready)", not Party.allReady(party))
check("add member", Party.addMember(party, 200, "Bob") and Party.count(party) == 2)
check("add duplicate fails", not Party.addMember(party, 200, "Bob"))
Party.setReady(party, 100, true)
Party.setReady(party, 200, true)
check("all ready when both ready", Party.allReady(party))
Party.removeMember(party, 100) -- leader leaves
check("member removed", Party.count(party) == 1)
check("leadership reassigned", party.leaderUserId == 200)

print(`\nResults: {passed} passed, {failed} failed`)
if failed > 0 then
	error(`{failed} test(s) failed`)
end
