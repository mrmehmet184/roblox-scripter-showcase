--!strict

local MathUtil = {}

function MathUtil.IsFiniteNumber(value: number): boolean
	return value == value and value > -math.huge and value < math.huge
end

function MathUtil.IsFiniteVector3(value: Vector3): boolean
	return MathUtil.IsFiniteNumber(value.X)
		and MathUtil.IsFiniteNumber(value.Y)
		and MathUtil.IsFiniteNumber(value.Z)
end

function MathUtil.SafeUnit(vector: Vector3, fallback: Vector3?): Vector3
	if vector.Magnitude < 1e-5 then
		return fallback or Vector3.zAxis
	end

	return vector.Unit
end

function MathUtil.ClosestPointOnSegment(point: Vector3, segmentStart: Vector3, segmentEnd: Vector3): Vector3
	local segment = segmentEnd - segmentStart
	local lengthSquared = segment:Dot(segment)

	if lengthSquared <= 1e-6 then
		return segmentStart
	end

	local alpha = math.clamp((point - segmentStart):Dot(segment) / lengthSquared, 0, 1)
	return segmentStart + segment * alpha
end

function MathUtil.DistancePointToSegment(point: Vector3, segmentStart: Vector3, segmentEnd: Vector3): number
	return (point - MathUtil.ClosestPointOnSegment(point, segmentStart, segmentEnd)).Magnitude
end

return MathUtil
