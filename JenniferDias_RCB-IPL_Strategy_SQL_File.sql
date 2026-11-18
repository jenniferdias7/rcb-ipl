/* =====================================================================
   RCB IPL STRATEGY — STUDENT ANSWER TEMPLATE
   ===================================================================== */

USE ipl;

/* =====================================================================
   OBJECTIVE QUESTIONS
   ===================================================================== */

-- O1
-- List the different dtypes of columns in table "ball_by_ball" (using
-- information schema)

SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE, COLUMN_KEY
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'ipl' AND TABLE_NAME = 'ball_by_ball';

-- O2
-- What is the total number of runs scored in 1st season by RCB (bonus: also
-- include the extra runs using the extra runs table)

SELECT
SUM(bs.Runs_Scored) AS bat_runs, 
COALESCE(SUM(e.Extra_Runs), 0) AS extra_runs, 
SUM(bs.Runs_Scored) + COALESCE(SUM(e.Extra_Runs), 0) AS total_with_extras
FROM batsman_scored bs
JOIN ball_by_ball b ON bs.Match_Id = b.Match_Id
AND bs.Over_Id = b.Over_Id 
AND bs.Ball_Id = b.Ball_id
AND bs.Innings_No = b.Innings_No
JOIN matches m ON b.Match_Id = m.Match_Id
JOIN team t ON b.Team_Batting = t.Team_Id
LEFT JOIN extra_runs e ON bs.Match_Id = e.Match_Id
AND bs.Over_Id = e.Over_Id 
AND bs.Ball_Id = e.Ball_Id
AND bs.Innings_No = e.Innings_No
AND bs.Over_Id = e.Over_Id 
AND bs.Ball_Id = e.Ball_Id
WHERE t.Team_Name = 'Royal Challengers Bangalore'
AND m.Season_Id = 1;

-- O3
-- How many players were more than the age of 25 during season 2014?

SELECT COUNT(DISTINCT p.Player_Id) AS players_over_25_in_2014
FROM player p
JOIN player_match pm ON p.Player_Id = pm.Player_Id
JOIN matches m ON pm.Match_Id = m.Match_Id
WHERE m.Season_Id = 7 AND TIMESTAMPDIFF(YEAR, p.DOB, '2014-01-01') > 25;

-- O4
-- How many matches did RCB win in 2013?

SELECT COUNT(*) AS rcb_wins_2013
FROM matches m
JOIN team t ON m.Match_Winner = t.Team_Id
WHERE t.Team_Name = 'Royal Challengers Bangalore'
AND m.Season_Id = 6;

-- O5
-- List the top 10 players according to their strike rate in the last 4
-- seasons

SELECT 
p.Player_Name,
SUM(bs.Runs_Scored) AS runs,
COUNT(b.Ball_Id) AS balls_faced,
ROUND((SUM(bs.Runs_Scored) / COUNT(b.Ball_Id)) * 100, 2) AS strike_rate
FROM player p
JOIN ball_by_ball b ON p.Player_Id = b.Striker
JOIN batsman_scored bs ON b.Match_Id = bs.Match_Id 
AND b.Over_Id = bs.Over_Id 
AND b.Ball_Id = bs.Ball_Id 
AND b.Innings_No = bs.Innings_No
JOIN matches m ON b.Match_Id = m.Match_Id
WHERE m.Season_Id IN (
SELECT Season_Id 
FROM (
SELECT DISTINCT Season_Id 
FROM matches 
ORDER BY Season_Id DESC LIMIT 4
) AS last_4_seasons
)
GROUP BY p.Player_Id, p.Player_Name
HAVING balls_faced >= 50
ORDER BY strike_rate DESC LIMIT 10;

-- O6
-- What are the average runs scored by each batsman considering all the
-- seasons?

SELECT 
p.Player_Name,
SUM(bs.Runs_Scored) AS total_runs,
COUNT(DISTINCT b.Match_Id) AS matches,
ROUND(SUM(bs.Runs_Scored) * 1.0 / COUNT(DISTINCT b.Match_Id), 2) AS avg_runs_per_match
FROM ball_by_ball b
JOIN batsman_scored bs ON b.Match_Id = bs.Match_Id 
AND b.Over_Id = bs.Over_Id 
AND b.Ball_Id = bs.Ball_Id 
AND b.Innings_No = bs.Innings_No
JOIN player p ON b.Striker = p.Player_Id
GROUP BY b.Striker, p.Player_Name
ORDER BY avg_runs_per_match DESC;

-- O7
-- What are the average wickets taken by each bowler considering all the
-- seasons?

SELECT p.Player_Name,
COUNT(w.Player_Out) AS total_wickets,
COUNT(DISTINCT b.Match_Id) AS matches,
ROUND(COUNT(w.Player_Out) * 1.0 / COUNT(DISTINCT b.Match_Id), 2) AS avg_wickets_per_match
FROM ball_by_ball b
JOIN wicket_taken w ON b.Match_Id = w.Match_Id 
AND b.Over_Id = w.Over_Id 
AND b.Ball_Id = w.Ball_Id 
AND b.Innings_No = w.Innings_No
LEFT JOIN out_type ot ON w.Kind_Out = ot.Out_Id
JOIN player p ON b.Bowler = p.Player_Id
WHERE ot.Out_Name NOT IN ('run out', 'retired hurt', 'obstructing the field') 
OR ot.Out_Name IS NULL
GROUP BY b.Bowler, p.Player_Name
HAVING COUNT(w.Player_Out) >= 1
ORDER BY avg_wickets_per_match DESC;

-- O8
-- List all the players who have average runs scored greater than the overall
-- average and who have taken wickets greater than the overall average

WITH player_batting AS (
SELECT 
p.Player_Id,
p.Player_Name,
ROUND(SUM(bs.Runs_Scored) / COUNT(DISTINCT b.Match_Id), 2) AS avg_runs
FROM player p
JOIN ball_by_ball b ON p.Player_Id = b.Striker
JOIN batsman_scored bs ON b.Match_Id = bs.Match_Id 
AND b.Over_Id = bs.Over_Id 
AND b.Ball_Id = bs.Ball_Id 
AND b.Innings_No = bs.Innings_No
GROUP BY p.Player_Id, p.Player_Name
),
player_bowling AS (
SELECT 
p.Player_Id,
p.Player_Name,
ROUND(COUNT(w.Player_Out) / COUNT(DISTINCT b.Match_Id), 2) AS avg_wkts
FROM player p
JOIN ball_by_ball b ON p.Player_Id = b.Bowler
JOIN wicket_taken w ON b.Match_Id = w.Match_Id 
AND b.Over_Id = w.Over_Id 
AND b.Ball_Id = w.Ball_Id 
AND b.Innings_No = w.Innings_No
LEFT JOIN out_type ot ON w.Kind_Out = ot.Out_Id
WHERE ot.Out_Name NOT IN ('run out', 'retired hurt', 'obstructing the field') 
OR ot.Out_Name IS NULL
GROUP BY p.Player_Id, p.Player_Name
),
overall_averages AS (
SELECT 
(SELECT AVG(avg_runs) FROM player_batting) AS overall_avg_runs,
(SELECT AVG(avg_wkts) FROM player_bowling) AS overall_avg_wkts
)
SELECT 
pb.Player_Name,
pb.avg_runs,
pw.avg_wkts
FROM player_batting pb
JOIN player_bowling pw ON pb.Player_Id = pw.Player_Id
CROSS JOIN overall_averages oa
WHERE pb.avg_runs > oa.overall_avg_runs
AND pw.avg_wkts > oa.overall_avg_wkts
ORDER BY pb.avg_runs DESC, pw.avg_wkts DESC;

-- O9
-- Create a table rcb_record table that shows the wins and losses of RCB in an
-- individual venue.

CREATE TABLE rcb_record (
    Venue_Id INT,
    Venue_Name VARCHAR(255),
    wins INT,
    losses INT
);
INSERT INTO rcb_record (Venue_Id, Venue_Name, wins, losses)
SELECT v.Venue_Id, v.Venue_Name,
SUM(CASE WHEN m.Match_Winner = rcb.Team_Id THEN 1 ELSE 0 END) AS wins,
SUM(CASE WHEN m.Match_Winner IS NOT NULL AND m.Match_Winner <> rcb.Team_Id THEN 1 ELSE 0 END) AS losses
FROM matches m
JOIN venue v ON m.Venue_Id = v.Venue_Id
JOIN team rcb ON rcb.Team_Name LIKE '%Royal Challengers%'
WHERE m.Team_1 = rcb.Team_Id OR m.Team_2 = rcb.Team_Id
GROUP BY v.Venue_Id, v.Venue_Name;

-- O10
-- What is the impact of bowling style on wickets taken?

SELECT 
bs.Bowling_Skill AS bowling_style,
COUNT(w.Player_Out) AS total_wickets,
COUNT(DISTINCT b.Bowler) AS num_bowlers,
ROUND(COUNT(w.Player_Out) / COUNT(DISTINCT b.Bowler), 2) AS wickets_per_bowler
FROM bowling_style bs
JOIN player p ON bs.Bowling_Id = p.Bowling_Skill
JOIN ball_by_ball b ON p.Player_Id = b.Bowler
JOIN wicket_taken w ON b.Match_Id = w.Match_Id 
AND b.Over_Id = w.Over_Id 
AND b.Ball_Id = w.Ball_Id 
AND b.Innings_No = w.Innings_No
LEFT JOIN out_type ot ON w.Kind_Out = ot.Out_Id
WHERE ot.Out_Name NOT IN ('run out', 'retired hurt', 'obstructing the field') 
OR ot.Out_Name IS NULL
GROUP BY bs.Bowling_Id, bs.Bowling_Skill
ORDER BY total_wickets DESC;

-- O11
-- Write the SQL query to provide a status of whether the performance of the
-- team is better than the previous year's performance on the basis of the
-- number of runs scored by the team in the season and the number of
-- wickets taken

WITH rcb_season_stats AS (
SELECT s.Season_Year,
SUM(bs.Runs_Scored) + COALESCE(SUM(e.Extra_Runs), 0) AS runs,
COUNT(DISTINCT w.Match_Id, w.Over_Id, w.Ball_Id, w.Innings_No) AS wkts
FROM season s
JOIN matches m ON s.Season_Id = m.Season_Id
JOIN team t ON t.Team_Name = 'Royal Challengers Bangalore'
JOIN ball_by_ball b ON m.Match_Id = b.Match_Id AND b.Team_Batting = t.Team_Id
JOIN batsman_scored bs ON b.Match_Id = bs.Match_Id 
AND b.Over_Id = bs.Over_Id 
AND b.Ball_Id = bs.Ball_Id 
AND b.Innings_No = bs.Innings_No
LEFT JOIN extra_runs e ON b.Match_Id = e.Match_Id 
AND b.Over_Id = e.Over_Id 
AND b.Ball_Id = e.Ball_Id 
AND b.Innings_No = e.Innings_No
LEFT JOIN wicket_taken w ON b.Match_Id = w.Match_Id 
AND b.Over_Id = w.Over_Id 
AND b.Ball_Id = w.Ball_Id 
AND b.Innings_No = w.Innings_No
WHERE s.Season_Year BETWEEN 2013 AND 2016
GROUP BY s.Season_Year
),
season_comparison AS (
SELECT Season_Year, runs, wkts,
LAG(runs) OVER (ORDER BY Season_Year) AS runs_vs_prev,
LAG(wkts) OVER (ORDER BY Season_Year) AS wkts_vs_prev
FROM rcb_season_stats
)
SELECT Season_Year, runs, wkts,
COALESCE(runs_vs_prev, 0) AS runs_vs_prev,
COALESCE(wkts_vs_prev, 0) AS wkts_vs_prev,
CASE 
WHEN runs_vs_prev IS NULL THEN 'N/A'
WHEN runs > runs_vs_prev AND wkts > wkts_vs_prev THEN 'Better'
WHEN runs < runs_vs_prev AND wkts < wkts_vs_prev THEN 'Worse'
ELSE 'Mixed'
END AS performance_status
FROM season_comparison
ORDER BY Season_Year ASC;

-- O12
-- Can you derive more KPIs for the team strategy?

SELECT 
s.Season_Year,
COUNT(m.Match_Id) AS played,
SUM(CASE WHEN m.Match_Winner = t.Team_Id THEN 1 ELSE 0 END) AS wins,
ROUND((SUM(CASE WHEN m.Match_Winner = t.Team_Id THEN 1 ELSE 0 END) / COUNT(m.Match_Id)) * 100, 2) AS win_pct
FROM season s
JOIN matches m ON s.Season_Id = m.Season_Id
JOIN team t ON t.Team_Name = 'Royal Challengers Bangalore'
WHERE (m.Team_1 = t.Team_Id OR m.Team_2 = t.Team_Id)
AND s.Season_Year BETWEEN 2013 AND 2016
GROUP BY s.Season_Year
ORDER BY s.Season_Year ASC;

SELECT 
ROUND((SUM(CASE WHEN bs.Runs_Scored IN (4, 6) THEN bs.Runs_Scored ELSE 0 END) / SUM(bs.Runs_Scored)) * 100, 2)
AS pct_runs_from_boundaries
FROM batsman_scored bs
JOIN ball_by_ball b ON bs.Match_Id = b.Match_Id 
AND bs.Over_Id = b.Over_Id 
AND bs.Ball_Id = b.Ball_Id 
AND bs.Innings_No = b.Innings_No
JOIN team t ON b.Team_Batting = t.Team_Id
WHERE t.Team_Name = 'Royal Challengers Bangalore';

SELECT 
p.Player_Name,
SUM(bs.Runs_Scored) AS runs
FROM player p
JOIN ball_by_ball b ON p.Player_Id = b.Striker
JOIN batsman_scored bs ON b.Match_Id = bs.Match_Id 
AND b.Over_Id = bs.Over_Id 
AND b.Ball_Id = bs.Ball_Id 
AND b.Innings_No = bs.Innings_No
JOIN team t ON b.Team_Batting = t.Team_Id
WHERE t.Team_Name = 'Royal Challengers Bangalore'
GROUP BY p.Player_Id, p.Player_Name
ORDER BY runs DESC LIMIT 5;

-- O13
-- Using SQL, write a query to find out the average wickets taken by each
-- bowler in each venue. Also, rank the gender according to the average
-- value.

SELECT v.Venue_Name, p.Player_Name,
COUNT(w.Player_Out) AS wickets,
ROUND(COUNT(w.Player_Out) * 1.0 / COUNT(DISTINCT b.Match_Id), 2) AS avg_wickets,
DENSE_RANK() OVER (PARTITION BY v.Venue_Id ORDER BY COUNT(w.Player_Out) * 1.0 / COUNT(DISTINCT b.Match_Id) DESC
) AS venue_rank
FROM ball_by_ball b
JOIN wicket_taken w ON b.Match_Id = w.Match_Id 
AND b.Over_Id = w.Over_Id 
AND b.Ball_Id = w.Ball_Id 
AND b.Innings_No = w.Innings_No
LEFT JOIN out_type ot ON w.Kind_Out = ot.Out_Id
JOIN player p ON b.Bowler = p.Player_Id
JOIN matches m ON b.Match_Id = m.Match_Id
JOIN venue v ON m.Venue_Id = v.Venue_Id
WHERE ot.Out_Name NOT IN ('run out', 'retired hurt', 'obstructing the field') 
OR ot.Out_Name IS NULL
GROUP BY v.Venue_Id, v.Venue_Name, b.Bowler, p.Player_Name
HAVING COUNT(w.Player_Out) >= 1
ORDER BY v.Venue_Name, venue_rank;

-- O14
-- Which of the given players have consistently performed well in past
-- seasons? (will you use any visualization to solve the problem)

WITH player_season_runs AS (
SELECT p.Player_Id, p.Player_Name, s.Season_Year,
COALESCE(SUM(bs.Runs_Scored), 0) AS season_runs
FROM player p
JOIN ball_by_ball b ON p.Player_Id = b.Striker
JOIN matches m ON b.Match_Id = m.Match_Id
JOIN season s ON m.Season_Id = s.Season_Id
LEFT JOIN batsman_scored bs ON b.Match_Id = bs.Match_Id 
AND b.Over_Id = bs.Over_Id 
AND b.Ball_Id = bs.Ball_Id 
AND b.Innings_No = bs.Innings_No
WHERE s.Season_Year BETWEEN 2013 AND 2016
GROUP BY p.Player_Id, p.Player_Name, s.Season_Year
),
player_consistency AS (
SELECT Player_Id, Player_Name,
COUNT(DISTINCT Season_Year) AS seasons_played,
ROUND(AVG(season_runs), 2) AS avg_runs_per_season,
MIN(season_runs) AS worst_season,
MAX(season_runs) AS best_season,
ROUND(COALESCE(STDDEV_SAMP(season_runs), 0), 2) AS runs_stddev
FROM player_season_runs
GROUP BY Player_Id, Player_Name
HAVING COUNT(DISTINCT Season_Year) = 4
)
SELECT 
Player_Name,
seasons_played,
avg_runs_per_season,
worst_season,
best_season,
runs_stddev
FROM player_consistency
ORDER BY avg_runs_per_season DESC;

-- O15
-- Are there players whose performance is more suited to specific venues or
-- conditions? (how would you present this using charts?)

SELECT 
p.Player_Name,
v.Venue_Name,
SUM(bs.Runs_Scored) AS runs,
COUNT(b.Ball_Id) AS balls,
ROUND((SUM(bs.Runs_Scored) / COUNT(b.Ball_Id)) * 100, 2) AS strike_rate
FROM player p
JOIN ball_by_ball b ON p.Player_Id = b.Striker
JOIN batsman_scored bs ON b.Match_Id = bs.Match_Id 
AND b.Over_Id = bs.Over_Id 
AND b.Ball_Id = bs.Ball_Id 
AND b.Innings_No = bs.Innings_No
JOIN matches m ON b.Match_Id = m.Match_Id
JOIN venue v ON m.Venue_Id = v.Venue_Id
GROUP BY p.Player_Id, p.Player_Name, v.Venue_Id, v.Venue_Name
HAVING COUNT(b.Ball_Id) >= 60
ORDER BY strike_rate DESC LIMIT 25;


/* =====================================================================
   SUBJECTIVE QUESTIONS
   ===================================================================== */

-- S1
-- How does the toss decision affect the result of the match? (which
-- visualizations could be used to present your answer better) And is the
-- impact limited to only specific venues?

SELECT 
v.Venue_Name,
td.Toss_Name AS toss_decision,
COUNT(m.Match_Id) AS total_matches,
SUM(CASE WHEN m.Toss_Winner = m.Match_Winner THEN 1 ELSE 0 END) AS toss_and_match_wins,
ROUND((SUM(CASE WHEN m.Toss_Winner = m.Match_Winner THEN 1 ELSE 0 END) * 100.0 / COUNT(m.Match_Id)),2) 
AS win_percentage
FROM matches m
JOIN venue v ON m.Venue_Id = v.Venue_Id
JOIN toss_decision td ON m.Toss_Decide = td.Toss_Id
GROUP BY v.Venue_Id, v.Venue_Name, td.Toss_Id, td.Toss_Name
HAVING COUNT(m.Match_Id) >= 10
ORDER BY v.Venue_Name, toss_decision;

-- S2
-- Suggest some of the players who would be best fit for the team.

WITH Batting_Stats AS (
SELECT b.Striker AS Player_Id,
SUM(bs.Runs_Scored) AS total_runs,
COUNT(b.Ball_Id) AS balls_faced,
ROUND((SUM(bs.Runs_Scored) * 100.0 / COUNT(b.Ball_Id)), 2) AS strike_rate
FROM ball_by_ball b
JOIN batsman_scored bs ON b.Match_Id = bs.Match_Id 
AND b.Over_Id = bs.Over_Id 
AND b.Ball_Id = bs.Ball_Id 
AND b.Innings_No = bs.Innings_No
GROUP BY b.Striker 
HAVING COUNT(b.Ball_Id) >= 200
),
Bowling_Stats AS (
SELECT b.Bowler AS Player_Id,
SUM(bs.Runs_Scored) AS runs_conceded,
COUNT(b.Ball_Id) AS balls_bowled,
ROUND(SUM(bs.Runs_Scored) / (COUNT(b.Ball_Id) / 6.0), 2) AS economy_rate,
COUNT(w.Player_Out) AS wickets
FROM ball_by_ball b
JOIN batsman_scored bs ON b.Match_Id = bs.Match_Id 
AND b.Over_Id = bs.Over_Id 
AND b.Ball_Id = bs.Ball_Id 
AND b.Innings_No = bs.Innings_No
LEFT JOIN wicket_taken w ON b.Match_Id = w.Match_Id 
AND b.Over_Id = w.Over_Id 
AND b.Ball_Id = w.Ball_Id 
AND b.Innings_No = w.Innings_No
LEFT JOIN out_type ot ON w.Kind_Out = ot.Out_Id
WHERE ot.Out_Name NOT IN ('run out', 'retired hurt', 'obstructing the field') 
OR ot.Out_Name IS NULL
GROUP BY b.Bowler
HAVING COUNT(b.Ball_Id) >= 200
)
SELECT p.Player_Name,
COALESCE(bat.strike_rate, 0.00) AS strike_rate,
COALESCE(bowl.economy_rate, 0.00) AS economy_rate,
COALESCE(bowl.wickets, 0) AS wickets
FROM player p
LEFT JOIN Batting_Stats bat ON p.Player_Id = bat.Player_Id
LEFT JOIN Bowling_Stats bowl ON p.Player_Id = bowl.Player_Id
WHERE bat.strike_rate > 135.0 OR bowl.economy_rate < 7.5
ORDER BY strike_rate DESC, economy_rate ASC;

-- S3
-- What are some of the parameters that should be focused on while selecting
-- the players?

SELECT p.Player_Name,
SUM(bs.Runs_Scored) AS total_runs,
COUNT(b.Ball_Id) AS balls_faced,
ROUND((SUM(bs.Runs_Scored) * 100.0 / COUNT(b.Ball_Id)), 2) AS overall_strike_rate,
ROUND((SUM(CASE WHEN bs.Runs_Scored IN (4, 6) THEN bs.Runs_Scored ELSE 0 END) * 100.0 
/ NULLIF(SUM(bs.Runs_Scored), 0)), 2) AS boundary_reliance_pct,
ROUND((SUM(CASE WHEN bs.Runs_Scored = 0 THEN 1 ELSE 0 END) * 100.0 / COUNT(b.Ball_Id)), 2
) AS dot_ball_pct
FROM ball_by_ball b
JOIN batsman_scored bs ON b.Match_Id = bs.Match_Id 
AND b.Over_Id = bs.Over_Id 
AND b.Ball_Id = bs.Ball_Id 
AND b.Innings_No = bs.Innings_No
JOIN player p ON b.Striker = p.Player_Id
GROUP BY b.Striker, p.Player_Name
HAVING COUNT(b.Ball_Id) >= 150
ORDER BY overall_strike_rate DESC;

-- S4
-- Which players offer versatility in their skills and can contribute
-- effectively with both bat and ball? (can you visualize the data for the
-- same)

WITH Batting_Stats AS (
SELECT b.Striker AS Player_Id,
SUM(bs.Runs_Scored) AS total_runs,
COUNT(b.Ball_Id) AS balls_faced,
ROUND((SUM(bs.Runs_Scored) * 100.0 / COUNT(b.Ball_Id)), 2) AS strike_rate
FROM ball_by_ball b
JOIN batsman_scored bs ON b.Match_Id = bs.Match_Id 
AND b.Over_Id = bs.Over_Id 
AND b.Ball_Id = bs.Ball_Id 
AND b.Innings_No = bs.Innings_No
GROUP BY b.Striker
HAVING SUM(bs.Runs_Scored) >= 300
),
Bowling_Stats AS (
SELECT b.Bowler AS Player_Id,
SUM(bs.Runs_Scored) AS runs_conceded,
COUNT(b.Ball_Id) AS balls_bowled,
ROUND(SUM(bs.Runs_Scored) / (COUNT(b.Ball_Id) / 6.0), 2) AS economy_rate,
COUNT(w.Player_Out) AS wickets
FROM ball_by_ball b
JOIN batsman_scored bs 
ON b.Match_Id = bs.Match_Id 
AND b.Over_Id = bs.Over_Id 
AND b.Ball_Id = bs.Ball_Id 
AND b.Innings_No = bs.Innings_No
LEFT JOIN wicket_taken w 
ON b.Match_Id = w.Match_Id 
AND b.Over_Id = w.Over_Id 
AND b.Ball_Id = w.Ball_Id 
AND b.Innings_No = w.Innings_No
LEFT JOIN out_type ot ON w.Kind_Out = ot.Out_Id
WHERE ot.Out_Name NOT IN ('run out', 'retired hurt', 'obstructing the field') 
OR ot.Out_Name IS NULL
GROUP BY b.Bowler
HAVING COUNT(w.Player_Out) >= 15
)
SELECT p.Player_Name, bat.total_runs, bat.strike_rate, bowl.wickets, bowl.economy_rate,
ROUND(bat.total_runs * bowl.wickets / 100.0, 2) AS allrounder_impact_score
FROM player p
INNER JOIN Batting_Stats bat ON p.Player_Id = bat.Player_Id
INNER JOIN Bowling_Stats bowl ON p.Player_Id = bowl.Player_Id
ORDER BY allrounder_impact_score DESC;

-- S5
-- Are there players whose presence positively influences the morale and
-- performance of the team? (justify your answer using visualization)

WITH RCB_Team AS (
SELECT Team_Id 
FROM team 
WHERE Team_Name LIKE '%Royal Challengers%' LIMIT 1
),
RCB_Matches AS (
SELECT m.Match_Id, m.Match_Winner, (m.Match_Winner = r.Team_Id) AS is_rcb_win
FROM matches m
JOIN RCB_Team r ON m.Team_1 = r.Team_Id OR m.Team_2 = r.Team_Id
),
Total_RCB_Stats AS (
SELECT COUNT(Match_Id) AS total_matches,
SUM(CASE WHEN is_rcb_win THEN 1 ELSE 0 END) AS total_wins
FROM RCB_Matches
),
Player_RCB_Matches AS (
SELECT p.Player_Id, p.Player_Name,
COUNT(DISTINCT rm.Match_Id) AS matches_played,
COUNT(DISTINCT CASE WHEN rm.is_rcb_win THEN rm.Match_Id END) AS wins_when_played
FROM ball_by_ball b
JOIN RCB_Matches rm ON b.Match_Id = rm.Match_Id
JOIN player p ON (b.Striker = p.Player_Id OR b.Bowler = p.Player_Id)
GROUP BY p.Player_Id, p.Player_Name
HAVING matches_played >= 15
)
SELECT pm.Player_Name, pm.matches_played,
ROUND((pm.wins_when_played * 100.0 / pm.matches_played), 2) AS win_pct_with_player,
(t.total_matches - pm.matches_played) AS matches_missed,
ROUND(((t.total_wins - pm.wins_when_played) * 100.0 / NULLIF((t.total_matches - pm.matches_played), 0)), 2) 
AS win_pct_without_player
FROM Player_RCB_Matches pm
CROSS JOIN Total_RCB_Stats t
ORDER BY win_pct_with_player DESC;

-- S6
-- What would you suggest to RCB before going to the mega auction?

WITH Pitch_Specialists AS (
SELECT p.Player_Name,
COUNT(b.Ball_Id) AS balls_bowled,
SUM(bs.Runs_Scored) AS total_runs,
COUNT(w.Player_Out) AS wickets,
ROUND(SUM(bs.Runs_Scored) / (COUNT(b.Ball_Id) / 6.0), 2) AS economy_rate,
ROUND(COUNT(w.Player_Out) * 6.0 / NULLIF(COUNT(b.Ball_Id), 0), 2) AS bowling_strike_rate
FROM ball_by_ball b
JOIN batsman_scored bs ON b.Match_Id = bs.Match_Id 
AND b.Over_Id = bs.Over_Id 
AND b.Ball_Id = bs.Ball_Id 
AND b.Innings_No = bs.Innings_No
LEFT JOIN wicket_taken w ON b.Match_Id = w.Match_Id 
AND b.Over_Id = w.Over_Id 
AND b.Ball_Id = w.Ball_Id 
AND b.Innings_No = w.Innings_No
JOIN player p ON b.Bowler = p.Player_Id
WHERE b.Over_Id <= 6 OR b.Over_Id >= 16
GROUP BY p.Player_Id, p.Player_Name
HAVING balls_bowled >= 180
)
SELECT Player_Name, balls_bowled / 6 AS overs_bowled, economy_rate, wickets, bowling_strike_rate
FROM Pitch_Specialists
WHERE economy_rate <= 8.20
ORDER BY economy_rate ASC;

-- S7
-- What do you think could be the factors contributing to the high-scoring
-- matches and the impact on viewership and team strategies

SELECT m.Venue_Id, v.Venue_Name,
COUNT(DISTINCT m.Match_Id) AS total_matches,
ROUND(SUM(bs.Runs_Scored) / (COUNT(DISTINCT m.Match_Id) * 2.0), 2) AS avg_score_per_innings,
SUM(CASE WHEN bs.Runs_Scored = 4 THEN 1 ELSE 0 END) AS total_fours,
SUM(CASE WHEN bs.Runs_Scored = 6 THEN 1 ELSE 0 END) AS total_sixes,
ROUND((SUM(CASE WHEN bs.Runs_Scored IN (4, 6) THEN bs.Runs_Scored ELSE 0 END) * 100.0 / NULLIF(SUM(bs.Runs_Scored), 0)), 2) 
AS boundary_run_pct
FROM matches m
JOIN venue v ON m.Venue_Id = v.Venue_Id
JOIN ball_by_ball b ON m.Match_Id = b.Match_Id
JOIN batsman_scored bs ON b.Match_Id = bs.Match_Id 
AND b.Over_Id = bs.Over_Id 
AND b.Ball_Id = bs.Ball_Id 
AND b.Innings_No = bs.Innings_No
GROUP BY m.Venue_Id, v.Venue_Name
HAVING total_matches >= 10
ORDER BY avg_score_per_innings DESC;

-- S8
-- Analyze the impact of home-ground advantage on team performance and
-- identify strategies to maximize this advantage for RCB.

WITH Match_Data AS (
SELECT m.Match_Id, m.Venue_Id, v.Venue_Name, m.Match_Winner, t.Team_Id AS RCB_Id,
(CASE WHEN m.Venue_Id = 1 THEN 'Home (Chinnaswamy)' ELSE 'Away / Neutral' END) AS venue_category
FROM matches m
JOIN team t ON t.Team_Name LIKE '%Royal Challengers%'
JOIN venue v ON m.Venue_Id = v.Venue_Id
WHERE m.Team_1 = t.Team_Id OR m.Team_2 = t.Team_Id
)
SELECT venue_category,
COUNT(Match_Id) AS total_matches,
SUM(CASE WHEN Match_Winner = RCB_Id THEN 1 ELSE 0 END) AS rcb_wins,
ROUND((SUM(CASE WHEN Match_Winner = RCB_Id THEN 1 ELSE 0 END) * 100.0 / COUNT(Match_Id)), 2) AS win_percentage
FROM Match_Data
GROUP BY venue_category;

-- S9
-- Come up with a visual and analytical analysis of the RCB's past season's
-- performance and potential reasons for them not winning a trophy.

SELECT m.Season_Id,
COUNT(DISTINCT m.Match_Id) AS total_matches,
SUM(bs.Runs_Scored) AS total_rcb_runs,
SUM(CASE WHEN b.Striker_Batting_Position IN (1, 2, 3) THEN bs.Runs_Scored ELSE 0 END) AS top_order_runs,
ROUND(
(SUM(CASE WHEN b.Striker_Batting_Position IN (1, 2, 3) THEN bs.Runs_Scored ELSE 0 END) * 100.0 / NULLIF(SUM(bs.Runs_Scored), 0)), 2) 
AS top_order_run_pct,
SUM(CASE WHEN b.Striker_Batting_Position >= 4 THEN bs.Runs_Scored ELSE 0 END) AS middle_lower_runs,
ROUND((SUM(CASE WHEN b.Striker_Batting_Position >= 4 THEN bs.Runs_Scored ELSE 0 END) * 100.0 / NULLIF(SUM(bs.Runs_Scored), 0)), 2) 
AS middle_lower_run_pct
FROM matches m
JOIN team t ON t.Team_Name LIKE '%Royal Challengers%'
JOIN ball_by_ball b ON m.Match_Id = b.Match_Id
JOIN batsman_scored bs ON b.Match_Id = bs.Match_Id 
AND b.Over_Id = bs.Over_Id 
AND b.Ball_Id = bs.Ball_Id 
AND b.Innings_No = bs.Innings_No
WHERE (m.Team_1 = t.Team_Id OR m.Team_2 = t.Team_Id)
AND b.Team_Batting = t.Team_Id
GROUP BY m.Season_Id
ORDER BY m.Season_Id DESC;

-- S10
-- How would you approach this problem, if the objective and subjective
-- questions weren't given?

-- no code

-- S11
-- In the "Match" table, some entries in the "Opponent_Team" column are
-- incorrectly spelled as "Delhi_Capitals" instead of "Delhi_Daredevils".
-- Write an SQL query to replace all occurrences of "Delhi_Capitals" with
-- "Delhi_Daredevils".

UPDATE team 
SET Team_Name = 'Delhi Daredevils' 
WHERE Team_Name = 'Delhi Capitals';

/* ===================================== END OF FILE ===================================== */
