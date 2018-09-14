local xpnn_const = {}

xpnn_const.CD_TYPE = {
	
}

xpnn_const.GAME_STATE = {
	ready_begin = 0, --用到
	gaming = 1,  --用到
	qiang_banker = 2, 
	bet = 3,	
	open_card = 4, 
	game_end = 5,  --用到
	exit = 6, --用到
}

xpnn_const.MAX_QIANG_BANKER_TIMES = 4
xpnn_const.MAX_BET_TIMES = 5

return xpnn_const