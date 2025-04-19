#!/bin/bash

YEAR=$( date '+%Y' )
MONTH=$( date '+%m' )
DAY=$( date '+%d' )
echo  fzf Daily/$MONTH-$DAY-$YEAR.md | xargs -r nvim
