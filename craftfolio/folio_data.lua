CRAFTCAL_FOLIO_DATA = {
	recipes = {
		{
			id = 5462,
			name = "Hereafter Stone",
			outputQuantity = 10,
			iconPath = "ui/icon/icon_item_0418.dds",
			workbench = "Stonemason Workbench",
			source = "ArcheRage Crafting Folio",
			materials = {
				{ name = "Stone Brick", quantity = 6, iconPath = "ui/icon/icon_item_0283.dds" },
			},
		},
		{
			id = 9256,
			name = "Golden Die",
			outputQuantity = 5,
			iconPath = "ui/icon/icon_item_3525.dds",
			workbench = "Grand Improved Workbench",
			vocation = "Masonry",
			proficiency = 230000,
			labor = 100,
			source = "ArcheRage Crafting Folio",
			materials = {
				{ name = "Sturdy Stone", quantity = 1, iconPath = "ui/icon/icon_item_0349.dds" },
				{ name = "Gold Ingot", quantity = 5, iconPath = "ui/icon/icon_item_0324.dds" },
				{ name = "Lily", quantity = 10, iconPath = "ui/icon/icon_item_0575.dds" },
			},
		},
		{
			name = "Sturdy Stone",
			outputQuantity = 1,
			iconPath = "ui/icon/icon_item_0349.dds",
			vocation = "Masonry",
			source = "Golden Die dependency",
			materials = {
				{ name = "Stone Brick", quantity = 10, iconPath = "ui/icon/icon_item_0283.dds" },
				{ name = "Opaque Polish", quantity = 1, iconPath = "ui/icon/icon_item_0644.dds" },
			},
		},
		{
			name = "Stone Brick",
			outputQuantity = 1,
			iconPath = "ui/icon/icon_item_0283.dds",
			vocation = "Masonry",
			source = "Golden Die dependency",
			materials = {
				{ name = "Raw Stone", quantity = 3, iconPath = "ui/icon/icon_item_0047.dds" },
			},
		},
		{
			name = "Opaque Polish",
			outputQuantity = 1,
			iconPath = "ui/icon/icon_item_0644.dds",
			source = "Golden Die dependency",
			materials = {
				{ name = "Onyx Archeum Essence", quantity = 3, iconPath = "ui/icon/icon_item_4457.dds" },
				{ name = "Azalea", quantity = 20, iconPath = "ui/icon/icon_item_0030.dds" },
				{ name = "Narcissus", quantity = 20, iconPath = "ui/icon/icon_item_0582.dds" },
			},
		},
		{
			name = "Gold Ingot",
			outputQuantity = 1,
			iconPath = "ui/icon/icon_item_0324.dds",
			source = "Golden Die dependency",
			materials = {
				{ name = "Gold Ore", quantity = 3, iconPath = "ui/icon/icon_item_0155.dds" },
			},
		},
	},
}
