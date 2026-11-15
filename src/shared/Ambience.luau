--!strict
-- Light, air and sky of the world (issue 85). The server calls setup once; the server and every client then call
-- apply with a mood from Core/DayCycle. Effects that a place already has are reused, never doubled.
local Lighting = game:GetService("Lighting")

local Ambience = {}

local function color(value: { number }): Color3
	return Color3.new(value[1] / 255, value[2] / 255, value[3] / 255)
end

local function child(parent: Instance, className: string): any
	local found = parent:FindFirstChildOfClass(className)
	if found == nil then
		found = Instance.new(className) :: Instance
		found.Parent = parent
	end
	return found
end

-- Creates sky, air, clouds and the screen effects, and sets everything that does not change during the day.
function Ambience.setup()
	Lighting.GlobalShadows = true
	Lighting.GeographicLatitude = 28
	Lighting.ShadowSoftness = 0.3
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1

	local sky: Sky = child(Lighting, "Sky")
	sky.StarCount = 4500
	sky.SunAngularSize = 15
	sky.MoonAngularSize = 9

	local atmosphere: Atmosphere = child(Lighting, "Atmosphere")
	atmosphere.Offset = 0.1

	local bloom: BloomEffect = child(Lighting, "BloomEffect")
	bloom.Size = 30
	bloom.Threshold = 1.3

	local rays: SunRaysEffect = child(Lighting, "SunRaysEffect")
	rays.Spread = 0.7

	child(Lighting, "ColorCorrectionEffect")

	local clouds: Clouds = child(workspace.Terrain, "Clouds")
	clouds.Cover = 0.56
	clouds.Density = 0.6
	clouds.Color = Color3.fromRGB(255, 240, 228)
end

-- Sets the look for one mood. Effects that are not there yet (still replicating) are skipped.
function Ambience.apply(mood: any)
	Lighting.Brightness = mood.brightness
	Lighting.ExposureCompensation = mood.exposure
	Lighting.Ambient = color(mood.ambient)
	Lighting.OutdoorAmbient = color(mood.outdoor)
	Lighting.ColorShift_Top = color(mood.shift)

	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere ~= nil then
		atmosphere.Density = mood.density
		atmosphere.Haze = mood.haze
		atmosphere.Glare = mood.glare
		atmosphere.Color = color(mood.air)
		atmosphere.Decay = color(mood.decay)
	end
	local correction = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
	if correction ~= nil then
		correction.TintColor = color(mood.tint)
		correction.Saturation = mood.saturation
		correction.Contrast = mood.contrast
	end
	local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
	if bloom ~= nil then
		bloom.Intensity = mood.bloom
	end
	local rays = Lighting:FindFirstChildOfClass("SunRaysEffect")
	if rays ~= nil then
		rays.Intensity = mood.rays
	end
end

return Ambience
