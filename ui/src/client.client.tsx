import React from "@rbxts/react";
import { createRoot } from "@rbxts/react-roblox";
import { Hud } from "components/Hud";

const Players = game.GetService("Players");
const player = Players.LocalPlayer;
const playerGui = player.WaitForChild("PlayerGui") as PlayerGui;

const screenGui = new Instance("ScreenGui");
screenGui.Name = "HudGui";
screenGui.ResetOnSpawn = false;
screenGui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets;
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling;
screenGui.Parent = playerGui;

const root = createRoot(screenGui);
root.render(<Hud />);
