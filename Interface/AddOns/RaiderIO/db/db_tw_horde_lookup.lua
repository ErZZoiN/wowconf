--
-- Copyright (c) 2020 by Ludicrous Speed, LLC
-- All rights reserved.
--
local provider={name=...,data=1,region="tw",faction=2,date="2020-12-05T06:00:30Z",currentSeasonId=0,numCharacters=0,lookup2={},recordSizeInBytes=25,encodingOrder={1,2,3,4,5,6,7,8,9,10,11}}
local F

-- chunk size: 0
F = function() provider.lookup2[1] = "" end F()

F = nil
RaiderIO.AddProvider(provider)
