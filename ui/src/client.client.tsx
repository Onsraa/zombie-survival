import React from "@rbxts/react";
import { createRoot } from "@rbxts/react-roblox";
import { Hud } from "components/Hud";

const Players = game.GetService("Players");
const player = Players.LocalPlayer;
const playerGui = player.WaitForChild("PlayerGui") as PlayerGui;

const screenGui = new Instance("ScreenGui");
screenGui.Name = "HudGui";
screenGui.ResetOnSpawn = false;
// None = the GUI's (0.5,0.5) is the true viewport center, so the crosshair aligns
// with where the camera shoots. Panels are positioned to clear the Roblox topbar.
screenGui.ScreenInsets = Enum.ScreenInsets.None;
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling;
screenGui.Parent = playerGui;

const root = createRoot(screenGui);
root.render(<Hud />);
