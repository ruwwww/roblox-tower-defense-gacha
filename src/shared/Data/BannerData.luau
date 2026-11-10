--!strict

export type BannerDefinition = {
	Id: string,
	Name: string,
	Description: string,
	Rates: {
		[number]: number, -- Rarity (3, 4, 5, 6) -> Probability (0 to 1)
	},
	PityEpicThreshold: number, -- Pulls until guaranteed 5★
	PityLegendaryThreshold: number, -- Pulls until guaranteed 6★
	FeaturedUnits: { string },
}

local Banners: { [string]: BannerDefinition } = {
	standard = {
		Id = "standard",
		Name = "Heroic Legends Summon",
		Description = "Summon mighty defenders! 10 pulls guarantee a 5★ Epic, 50 pulls guarantee a 6★ Legendary!",
		Rates = {
			[3] = 0.700, -- 70%
			[4] = 0.250, -- 25%
			[5] = 0.045, -- 4.5%
			[6] = 0.005, -- 0.5%
		},
		PityEpicThreshold = 10,
		PityLegendaryThreshold = 50,
		FeaturedUnits = { "solar_paladin", "chrono_overlord", "sniper_assassin" },
	},
}

local BannerData = {
	Banners = Banners,
	RarityUnits = {
		[3] = { "archer", "rock_slinger" },
		[4] = { "frost_mage", "cannoneer" },
		[5] = { "storm_shaman", "sniper_assassin" },
		[6] = { "solar_paladin", "chrono_overlord" },
	},
}

function BannerData.Get(bannerId: string): BannerDefinition?
	return Banners[bannerId] or Banners.standard
end

return BannerData
