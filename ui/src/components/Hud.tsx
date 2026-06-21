import React, { useEffect, useState } from "@rbxts/react";
import { getRemote, RemoteNames, RoundSnapshot, WeaponSnapshot, StatsSnapshot } from "shared/remotes";

const Players = game.GetService("Players");

const PANEL_BG = Color3.fromRGB(15, 15, 18);
const ACCENT = Color3.fromRGB(120, 200, 90);
const DANGER = Color3.fromRGB(200, 60, 60);
const WHITE = new Color3(1, 1, 1);

function Panel(
	props: React.PropsWithChildren<{ anchor: Vector2; position: UDim2; size: UDim2 }>,
) {
	return (
		<frame
			AnchorPoint={props.anchor}
			Position={props.position}
			Size={props.size}
			BackgroundColor3={PANEL_BG}
			BackgroundTransparency={0.35}
			BorderSizePixel={0}
		>
			<uicorner CornerRadius={new UDim(0, 8)} />
			{props.children}
		</frame>
	);
}

function Label(props: {
	text: string;
	color: Color3;
	align?: Enum.TextXAlignment;
	font?: Enum.Font;
}) {
	return (
		<textlabel
			Size={UDim2.fromScale(1, 1)}
			BackgroundTransparency={1}
			Text={props.text}
			TextColor3={props.color}
			TextScaled={true}
			Font={props.font ?? Enum.Font.GothamBold}
			TextXAlignment={props.align ?? Enum.TextXAlignment.Center}
		>
			<uipadding
				PaddingLeft={new UDim(0, 10)}
				PaddingRight={new UDim(0, 10)}
				PaddingTop={new UDim(0, 4)}
				PaddingBottom={new UDim(0, 4)}
			/>
		</textlabel>
	);
}

function Crosshair() {
	const LEN = 8;
	const THICK = 2;
	const GAP = 5;
	return (
		<frame
			AnchorPoint={new Vector2(0.5, 0.5)}
			Position={UDim2.fromScale(0.5, 0.5)}
			Size={UDim2.fromOffset(40, 40)}
			BackgroundTransparency={1}
		>
			<frame
				AnchorPoint={new Vector2(0.5, 1)}
				Position={new UDim2(0.5, 0, 0.5, -GAP)}
				Size={UDim2.fromOffset(THICK, LEN)}
				BackgroundColor3={WHITE}
				BackgroundTransparency={0.15}
				BorderSizePixel={0}
			/>
			<frame
				AnchorPoint={new Vector2(0.5, 0)}
				Position={new UDim2(0.5, 0, 0.5, GAP)}
				Size={UDim2.fromOffset(THICK, LEN)}
				BackgroundColor3={WHITE}
				BackgroundTransparency={0.15}
				BorderSizePixel={0}
			/>
			<frame
				AnchorPoint={new Vector2(1, 0.5)}
				Position={new UDim2(0.5, -GAP, 0.5, 0)}
				Size={UDim2.fromOffset(LEN, THICK)}
				BackgroundColor3={WHITE}
				BackgroundTransparency={0.15}
				BorderSizePixel={0}
			/>
			<frame
				AnchorPoint={new Vector2(0, 0.5)}
				Position={new UDim2(0.5, GAP, 0.5, 0)}
				Size={UDim2.fromOffset(LEN, THICK)}
				BackgroundColor3={WHITE}
				BackgroundTransparency={0.15}
				BorderSizePixel={0}
			/>
		</frame>
	);
}

function HitMarker(props: { headshot: boolean }) {
	const color = props.headshot ? Color3.fromRGB(255, 90, 90) : WHITE;
	const line = (rotation: number) => (
		<frame
			Rotation={rotation}
			AnchorPoint={new Vector2(0.5, 0.5)}
			Position={UDim2.fromScale(0.5, 0.5)}
			Size={UDim2.fromOffset(16, 2)}
			BackgroundColor3={color}
			BackgroundTransparency={0.1}
			BorderSizePixel={0}
		/>
	);
	return (
		<frame
			AnchorPoint={new Vector2(0.5, 0.5)}
			Position={UDim2.fromScale(0.5, 0.5)}
			Size={UDim2.fromOffset(22, 22)}
			BackgroundTransparency={1}
		>
			{line(45)}
			{line(-45)}
		</frame>
	);
}

export function Hud() {
	const [round, setRound] = useState<RoundSnapshot | undefined>(undefined);
	const [weapon, setWeapon] = useState<WeaponSnapshot | undefined>(undefined);
	const [stats, setStats] = useState<StatsSnapshot>({ points: 0, kills: 0 });
	const [health, setHealth] = useState(100);
	const [maxHealth, setMaxHealth] = useState(100);
	const [hitMarker, setHitMarker] = useState<{ headshot: boolean } | undefined>(undefined);

	useEffect(() => {
		const conns: RBXScriptConnection[] = [];

		const roundRemote = getRemote(RemoteNames.RoundState);
		if (roundRemote) conns.push(roundRemote.OnClientEvent.Connect((s) => setRound(s as RoundSnapshot)));

		const weaponRemote = getRemote(RemoteNames.WeaponState);
		if (weaponRemote) conns.push(weaponRemote.OnClientEvent.Connect((s) => setWeapon(s as WeaponSnapshot)));

		const statsRemote = getRemote(RemoteNames.PlayerStats);
		if (statsRemote) conns.push(statsRemote.OnClientEvent.Connect((s) => setStats(s as StatsSnapshot)));

		let hitId = 0;
		const shotResult = getRemote(RemoteNames.ShotResult);
		if (shotResult)
			conns.push(
				shotResult.OnClientEvent.Connect((headshot: boolean) => {
					hitId += 1;
					const myId = hitId;
					setHitMarker({ headshot });
					task.delay(0.15, () => {
						if (hitId === myId) setHitMarker(undefined);
					});
				}),
			);

		const player = Players.LocalPlayer;
		let humanoidConn: RBXScriptConnection | undefined;
		const bindCharacter = (char: Model) => {
			const humanoid = char.WaitForChild("Humanoid", 5) as Humanoid | undefined;
			if (humanoid === undefined) return;
			setHealth(humanoid.Health);
			setMaxHealth(humanoid.MaxHealth);
			humanoidConn?.Disconnect();
			humanoidConn = humanoid.HealthChanged.Connect((h) => {
				setHealth(h);
				setMaxHealth(humanoid.MaxHealth);
			});
		};
		if (player.Character) bindCharacter(player.Character);
		conns.push(player.CharacterAdded.Connect(bindCharacter));

		// Listeners are connected — ask the server to push current state now.
		const sync = getRemote(RemoteNames.RequestSync);
		sync?.FireServer();

		return () => {
			for (const c of conns) c.Disconnect();
			humanoidConn?.Disconnect();
		};
	}, []);

	let roundText = "...";
	if (round !== undefined) {
		if (round.phase === "Intermission") {
			roundText = `INTERMISSION ${round.timeLeft ?? ""}`;
		} else if (round.phase === "GameOver") {
			roundText = "GAME OVER";
		} else {
			roundText = `ROUND ${round.round}`;
		}
	}

	const healthPct = math.clamp(health / math.max(maxHealth, 1), 0, 1);
	const ammoText =
		weapon === undefined ? "—" : weapon.reloading ? "RELOADING" : `${weapon.magAmmo} / ${weapon.reserveAmmo}`;

	return (
		<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0}>
			<Crosshair />
			{hitMarker !== undefined ? <HitMarker headshot={hitMarker.headshot} /> : undefined}

			<Panel anchor={new Vector2(0.5, 0)} position={UDim2.fromScale(0.5, 0.03)} size={UDim2.fromScale(0.3, 0.07)}>
				<Label text={roundText} color={WHITE} />
			</Panel>

			<Panel anchor={new Vector2(0, 0)} position={UDim2.fromScale(0.02, 0.03)} size={UDim2.fromScale(0.18, 0.06)}>
				<Label text={`${stats.points} pts`} color={ACCENT} align={Enum.TextXAlignment.Left} />
			</Panel>

			<Panel anchor={new Vector2(1, 0)} position={UDim2.fromScale(0.98, 0.03)} size={UDim2.fromScale(0.2, 0.06)}>
				<Label
					text={`Zombies: ${round !== undefined ? round.zombiesRemaining : 0}`}
					color={WHITE}
					align={Enum.TextXAlignment.Right}
					font={Enum.Font.GothamMedium}
				/>
			</Panel>

			<Panel anchor={new Vector2(0, 1)} position={UDim2.fromScale(0.02, 0.97)} size={UDim2.fromScale(0.26, 0.06)}>
				<frame Size={UDim2.fromScale(1, 1)} BackgroundColor3={Color3.fromRGB(45, 45, 50)} BorderSizePixel={0}>
					<uicorner CornerRadius={new UDim(0, 8)} />
					<frame
						Size={UDim2.fromScale(healthPct, 1)}
						BackgroundColor3={healthPct > 0.3 ? ACCENT : DANGER}
						BorderSizePixel={0}
					>
						<uicorner CornerRadius={new UDim(0, 8)} />
					</frame>
					<Label text={`${math.floor(health)} / ${math.floor(maxHealth)}`} color={WHITE} />
				</frame>
			</Panel>

			<Panel anchor={new Vector2(1, 1)} position={UDim2.fromScale(0.98, 0.97)} size={UDim2.fromScale(0.22, 0.06)}>
				<Label
					text={ammoText}
					color={weapon !== undefined && weapon.reloading ? DANGER : WHITE}
					align={Enum.TextXAlignment.Right}
				/>
			</Panel>
		</frame>
	);
}
