--!strict

export type MatchSnapshot = {
	state: string,
	timeRemaining: number,
	result: string?,
	winnerUserId: number,
}

export type BossSnapshot = {
	name: string,
	state: string,
	health: number,
	maximumHealth: number,
	targetName: string?,
	alive: boolean,
}

export type TelemetrySnapshot = {
	accepted: number,
	rejected: number,
	lastEvent: string,
}

export type FullSnapshot = {
	match: MatchSnapshot,
	boss: BossSnapshot,
	telemetry: TelemetrySnapshot,
	version: string,
}

return {}
