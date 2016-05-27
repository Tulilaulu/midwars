# Course page
http://tkt-hon.github.io/midwars/

# tkt-hon Midwars Tourney

    Alias "create_midwars_botmatch_1v1" "set teambotmanager_legion; set teambotmanager_hellbourne; BotDebugEnable; StartGame practice test mode:botmatch map:midwars teamsize:1 spectators:1 allowduplicate:true; g_botDifficulty 3; g_camDistanceMax 10000; g_camDistanceMaxSpectator 10000;"
    Alias "create_midwars_botmatch" "set teambotmanager_legion; set teambotmanager_hellbourne; BotDebugEnable; StartGame practice test mode:botmatch map:midwars teamsize:5 spectators:1 allowduplicate:true; g_botDifficulty 3; g_camDistanceMax 10000; g_camDistanceMaxSpectator 10000;"

## Teams

### Default bots by organizers

    Alias "team_retk_legion" "set teambotmanager_legion retk; AddBot 1 RETK_Devourer; AddBot 1 RETK_MonkeyKing; AddBot 1 RETK_Nymphora; AddBot 1 RETK_PuppetMaster; AddBot 1 RETK_Valkyrie"

    Alias "team_retk_hellbourne" "set teambotmanager_hellbourne retk; AddBot 2 RETK_Devourer; AddBot 2 RETK_MonkeyKing; AddBot 2 RETK_Nymphora; AddBot 2 RETK_PuppetMaster; AddBot 2 RETK_Valkyrie"
