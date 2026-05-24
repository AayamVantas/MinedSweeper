---@diagnostic disable: undefined-global
return {
	MineColors = {
		Color.FromHex("#0000FFFF"), -- 1: Blue
		Color.FromHex("#008000FF"), -- 2: Green
		Color.FromHex("#FF0000FF"), -- 3: Red
		Color.FromHex("#000080FF"), -- 4: Dark Blue / Navy
		Color.FromHex("#800000FF"), -- 5: Dark Red / Maroon
		Color.FromHex("#008080FF"), -- 6: Teal / Cyan
		Color.FromHex("#000000FF"), -- 7: Black
		Color.FromHex("#808080FF"), -- 8: Gray
	},
    ObjectColors = {
        Mine = Color.New(1,0,0),
        Tile = Color.FromHex("#EEB65FFF"),
        Revealed = Color.New(.8,.8,.8),
    }
}