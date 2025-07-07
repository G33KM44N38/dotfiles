#!/bin/bash

YEAR=$( date '+%Y' )
MONTH=$( date '+%m' )
DAY=$( date '+%d' )
echo  fzf Daily/$YEAR-$MONTH-$DAY.md | xargs -r nvim
