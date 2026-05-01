package com.example.youthbaseballai

import android.os.Bundle
import android.content.Intent
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import android.net.Uri
import androidx.compose.foundation.clickable
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.rememberScrollState
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Switch
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Text
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExposedDropdownMenuBox
import androidx.compose.material3.ExposedDropdownMenuDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.example.youthbaseballai.ui.theme.YouthBaseballAITheme
import org.json.JSONArray
import org.json.JSONObject
import java.util.UUID

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            YouthBaseballAITheme {
                YouthBaseballAIApp()
            }
        }
    }
}

enum class FieldPosition(val label: String) {
    Pitcher("P"), Catcher("C"), FirstBase("1st"), SecondBase("2nd"), ThirdBase("3rd"),
    Shortstop("SS"), LeftField("LF"), CenterField("CF"), RightField("RF");

    companion object {
        val autoAssignedPositions = listOf(FirstBase, SecondBase, ThirdBase, Shortstop, LeftField, CenterField, RightField)
    }
}

enum class PlayerStatus { Active, Unavailable, Injured }

data class GameChangerStats(
    var avg: String = "—",
    var obp: String = "—",
    var ops: String = "—",
    var slg: String = "—",
    var hits: String = "—",
    var rbi: String = "—",
    var runs: String = "—",
    var walks: String = "—",
    var strikeouts: String = "—"
) {
    fun displayText(): String = "Stats: AVG $avg  OBP $obp  OPS $ops  SLG $slg  H $hits  RBI $rbi  R $runs  BB $walks  SO $strikeouts"
}

data class Player(
    val id: String = UUID.randomUUID().toString(),
    var name: String,
    var number: String = "",
    var stealRating: Int = 1,
    var status: PlayerStatus = PlayerStatus.Active,
    val positionRatings: MutableMap<FieldPosition, Int> = mutableMapOf(),
    var stats: GameChangerStats? = null
)

class LineupViewModel {
    var selectedTeamIndex by mutableIntStateOf(0)
        private set

    var teamNames = mutableStateListOf("Team 1", "Team 2")
        private set

    private val teamPlayers = listOf(
        mutableStateListOf<Player>(),
        mutableStateListOf<Player>()
    )

    private val teamLineups = listOf(
        mutableStateMapOf<FieldPosition, Player>(),
        mutableStateMapOf<FieldPosition, Player>()
    )

    private val teamInningLineups = listOf(
        mutableStateMapOf<Int, MutableMap<FieldPosition, Player>>(),
        mutableStateMapOf<Int, MutableMap<FieldPosition, Player>>()
    )

    private val teamInningPitcherIds = listOf(
        mutableStateMapOf<Int, String>(),
        mutableStateMapOf<Int, String>()
    )

    private val teamInningCatcherIds = listOf(
        mutableStateMapOf<Int, String>(),
        mutableStateMapOf<Int, String>()
    )

    private val teamSelectedInnings = mutableStateListOf(1, 1)

    private val teamBattingOrders = listOf(
        mutableStateListOf<String>(),
        mutableStateListOf<String>()
    )

    var showAssignedLineupTable by mutableStateOf(true)
    var showBenchOnField by mutableStateOf(true)
    var showFullNameAndNumber by mutableStateOf(true)
    var showOnlyNineBattersAndDH by mutableStateOf(false)
    var showRatingsOnField by mutableStateOf(true)
    var showSlowSpeedBattingWarnings by mutableStateOf(true)
    var gameChangerStatusMessage by mutableStateOf("")
    var backupStatusMessage by mutableStateOf("")

    val players: List<Player>
        get() = teamPlayers[selectedTeamIndex]

    val lineup: Map<FieldPosition, Player>
        get() = teamLineups[selectedTeamIndex]

    val selectedTeamName: String
        get() = teamNames[selectedTeamIndex]

    val activePlayers: List<Player>
        get() = players.filter { it.status == PlayerStatus.Active }

    val selectedInning: Int
        get() = teamSelectedInnings[selectedTeamIndex]

    val selectedPitcher: Player?
        get() = playerById(teamInningPitcherIds[selectedTeamIndex][selectedInning]) ?: lineup[FieldPosition.Pitcher]

    val selectedCatcher: Player?
        get() = playerById(teamInningCatcherIds[selectedTeamIndex][selectedInning]) ?: lineup[FieldPosition.Catcher]

    fun rankedPlayersForPosition(position: FieldPosition): List<Player> {
        return activePlayers.sortedWith(
            compareBy<Player> { it.positionRatings[position] ?: Int.MAX_VALUE }
                .thenBy { it.name.lowercase() }
        )
    }

    val battingOrderIds: MutableList<String>
        get() = teamBattingOrders[selectedTeamIndex]

    fun selectTeam(index: Int) {
        selectedTeamIndex = index.coerceIn(0, 1)
    }

    fun renameSelectedTeam(name: String) {
        val cleanName = name.trim()
        if (cleanName.isNotEmpty()) {
            teamNames[selectedTeamIndex] = cleanName
        }
    }

    fun addPlayer(name: String) {
        val cleanName = name.trim()
        if (cleanName.isNotEmpty()) {
            val player = Player(name = cleanName)
            teamPlayers[selectedTeamIndex].add(player)
            battingOrderIds.add(player.id)
        }
    }

    fun deletePlayer(player: Player) {
        teamPlayers[selectedTeamIndex].remove(player)
        battingOrderIds.removeAll { it == player.id }
        teamLineups[selectedTeamIndex].entries.removeAll { it.value.id == player.id }
        teamInningLineups[selectedTeamIndex].values.forEach { inningLineup ->
            inningLineup.entries.removeAll { it.value.id == player.id }
        }
        teamInningPitcherIds[selectedTeamIndex].entries.removeAll { it.value == player.id }
        teamInningCatcherIds[selectedTeamIndex].entries.removeAll { it.value == player.id }
    }

    fun assignPosition(position: FieldPosition, player: Player) {
        teamLineups[selectedTeamIndex].entries.removeAll { it.value.id == player.id }
        teamLineups[selectedTeamIndex][position] = player
        saveCurrentInningState()
        copyCurrentInningForwardIfNeeded()
    }

    fun clearPosition(position: FieldPosition) {
        teamLineups[selectedTeamIndex].remove(position)
        saveCurrentInningState()
    }

    fun clearLineup() {
        clearInning()
    }

    fun clearInning() {
        teamLineups[selectedTeamIndex].clear()
        teamInningLineups[selectedTeamIndex][selectedInning] = mutableStateMapOf()
        teamInningPitcherIds[selectedTeamIndex].remove(selectedInning)
        teamInningCatcherIds[selectedTeamIndex].remove(selectedInning)
    }

    fun clearAllInnings() {
        teamLineups[selectedTeamIndex].clear()
        teamInningLineups[selectedTeamIndex].clear()
        teamInningPitcherIds[selectedTeamIndex].clear()
        teamInningCatcherIds[selectedTeamIndex].clear()
    }

    fun selectInning(inning: Int) {
        saveCurrentInningState()
        teamSelectedInnings[selectedTeamIndex] = inning.coerceIn(1, 7)
        teamLineups[selectedTeamIndex].clear()
        teamLineups[selectedTeamIndex].putAll(teamInningLineups[selectedTeamIndex][selectedInning] ?: mutableMapOf())
        selectedPitcher?.let { teamLineups[selectedTeamIndex][FieldPosition.Pitcher] = it }
        selectedCatcher?.let { teamLineups[selectedTeamIndex][FieldPosition.Catcher] = it }
    }

    fun setCurrentLineupForAllInnings() {
        saveCurrentInningState()
        val pitcherId = selectedPitcher?.id
        val catcherId = selectedCatcher?.id
        for (inning in 1..7) {
            teamInningLineups[selectedTeamIndex][inning] = mutableStateMapOf<FieldPosition, Player>().also {
                it.putAll(teamLineups[selectedTeamIndex])
            }
            if (pitcherId != null) teamInningPitcherIds[selectedTeamIndex][inning] = pitcherId
            if (catcherId != null) teamInningCatcherIds[selectedTeamIndex][inning] = catcherId
        }
    }

    fun updatePlayer(player: Player, name: String, number: String, stealRating: Int) {
        player.name = name.trim().ifEmpty { player.name }
        player.number = number.trim()
        player.stealRating = stealRating
    }

    fun setPlayerStatus(player: Player, status: PlayerStatus) {
        player.status = status
        if (status != PlayerStatus.Active) {
            teamLineups[selectedTeamIndex].entries.removeAll { it.value.id == player.id }
            teamInningLineups[selectedTeamIndex].values.forEach { inningLineup ->
                inningLineup.entries.removeAll { it.value.id == player.id }
            }
            teamInningPitcherIds[selectedTeamIndex].entries.removeAll { it.value == player.id }
            teamInningCatcherIds[selectedTeamIndex].entries.removeAll { it.value == player.id }
        }
    }

    fun setRating(player: Player, position: FieldPosition, rating: Int) {
        player.positionRatings[position] = rating
    }

    fun removeRating(player: Player, position: FieldPosition) {
        player.positionRatings.remove(position)
    }

    fun autoFillLineup() {
        val assigned = mutableStateMapOf<FieldPosition, Player>()
        val usedIds = mutableSetOf<String>()

        for (position in listOf(FieldPosition.Pitcher, FieldPosition.Catcher)) {
            val current = lineup[position]
            if (current != null && current.status == PlayerStatus.Active && !usedIds.contains(current.id)) {
                assigned[position] = current
                usedIds.add(current.id)
            }
        }

        for (position in FieldPosition.autoAssignedPositions) {
            if (assigned[position] != null) continue
            val best = activePlayers
                .filter { !usedIds.contains(it.id) && it.positionRatings[position] != null }
                .sortedWith(compareBy<Player> { it.positionRatings[position] ?: 99 }.thenBy { it.name.lowercase() })
                .firstOrNull()
            if (best != null) {
                assigned[position] = best
                usedIds.add(best.id)
            }
        }

        teamLineups[selectedTeamIndex].clear()
        teamLineups[selectedTeamIndex].putAll(assigned)
        saveCurrentInningState()
        copyCurrentInningForwardIfNeeded()
    }

    fun benchPlayers(): List<Player> {
        val assignedIds = lineup.values.map { it.id }.toSet()
        return activePlayers.filter { !assignedIds.contains(it.id) }
    }

    fun placeBenchPlayerInField(player: Player) {
        val target = FieldPosition.autoAssignedPositions
            .filter { position -> player.positionRatings[position] != null }
            .sortedWith(compareBy<FieldPosition> { player.positionRatings[it] ?: Int.MAX_VALUE }.thenBy { it.label })
            .firstOrNull { position -> lineup[position] == null }
            ?: FieldPosition.autoAssignedPositions
                .sortedWith(compareBy<FieldPosition> { player.positionRatings[it] ?: Int.MAX_VALUE }.thenBy { it.label })
                .firstOrNull { position -> lineup[position] == null }
            ?: FieldPosition.autoAssignedPositions
                .minWithOrNull(compareBy<FieldPosition> { player.positionRatings[it] ?: Int.MAX_VALUE }.thenBy { it.label })
            ?: FieldPosition.FirstBase
        assignPosition(target, player)
    }

    fun displayLabel(player: Player): String {
        val parts = player.name.trim().split(Regex("\\s+")).filter { it.isNotBlank() }
        val last = parts.lastOrNull() ?: player.name
        val firstInitial = parts.firstOrNull()?.firstOrNull()?.let { "$it." } ?: ""
        val shortName = if (firstInitial.isEmpty()) last else "$firstInitial $last"
        return if (showFullNameAndNumber) {
            if (player.number.isBlank()) player.name else "#${player.number} ${player.name}"
        } else {
            if (player.number.isBlank()) shortName else "#${player.number} $shortName"
        }
    }

    fun syncBattingOrder() {
        val ids = players.map { it.id }.toSet()
        battingOrderIds.removeAll { !ids.contains(it) }
        players.forEach { if (!battingOrderIds.contains(it.id)) battingOrderIds.add(it.id) }
    }

    fun moveBatter(index: Int, direction: Int) {
        val target = (index + direction).coerceIn(0, battingOrderIds.lastIndex)
        if (target == index) return
        val id = battingOrderIds.removeAt(index)
        battingOrderIds.add(target, id)
    }

    fun lineupGridText(): String {
        syncBattingOrder()
        val orderedPlayers = battingOrderIds
            .mapNotNull { id -> players.firstOrNull { it.id == id } }
            .filter { it.status == PlayerStatus.Active }

        val builder = StringBuilder()
        builder.appendLine(selectedTeamName)
        builder.appendLine("Batter\tPlayer\t1\t2\t3\t4\t5\t6\t7")

        orderedPlayers.forEachIndexed { index, player ->
            builder.append(index + 1).append('\t').append(displayLabel(player))
            for (inning in 1..7) {
                val inningLineup = teamInningLineups[selectedTeamIndex][inning]
                    ?: if (inning == selectedInning) teamLineups[selectedTeamIndex] else emptyMap()
                val position = inningLineup.entries.firstOrNull { it.value.id == player.id }?.key
                builder.append('\t').append(position?.label ?: "X")
            }
            builder.appendLine()
        }

        return builder.toString()
    }

    fun lineupGridRows(): List<List<String>> {
        syncBattingOrder()
        val orderedPlayers = battingOrderIds
            .mapNotNull { id -> players.firstOrNull { it.id == id } }
            .filter { it.status == PlayerStatus.Active }

        val rows = mutableListOf<List<String>>()
        rows.add(listOf("Batter", "Player", "1", "2", "3", "4", "5", "6", "7"))

        orderedPlayers.forEachIndexed { index, player ->
            val row = mutableListOf<String>()
            row.add((index + 1).toString())
            row.add(displayLabel(player))
            for (inning in 1..7) {
                val inningLineup = teamInningLineups[selectedTeamIndex][inning]
                    ?: if (inning == selectedInning) teamLineups[selectedTeamIndex] else emptyMap()
                val position = inningLineup.entries.firstOrNull { it.value.id == player.id }?.key
                row.add(position?.label ?: "X")
            }
            rows.add(row)
        }

        return rows
    }

    fun lineupGridCsv(): String {
        val rows = mutableListOf<List<String>>()
        rows.add(listOf(selectedTeamName))
        rows.addAll(lineupGridRows())
        return rows.joinToString("\n") { row ->
            row.joinToString(",") { value -> csvEscape(value) }
        }
    }

    private fun csvEscape(value: String): String {
        val escaped = value.replace("\"", "\"\"")
        return if (escaped.contains(',') || escaped.contains('\n') || escaped.contains('\r') || escaped.contains('"')) {
            "\"$escaped\""
        } else {
            escaped
        }
    }

    fun clearGameChangerStats() {
        gameChangerStatusMessage = "GameChanger stats cleared."
    }

    fun exportSelectedTeamJson(): String {
        backupStatusMessage = "Selected team JSON created."
        return buildTeamJson(selectedTeamIndex).toString(2)
    }

    fun importGameChangerCsv(csvText: String) {
        val rows = parseCsv(csvText).filter { row -> row.any { it.isNotBlank() } }
        val headerIndex = rows.indexOfFirst { row ->
            val normalized = row.map { normalizeHeader(it) }
            normalized.contains("first") && normalized.contains("last")
        }

        if (headerIndex < 0 || headerIndex >= rows.lastIndex) {
            gameChangerStatusMessage = "Import failed: could not find First/Last header row."
            return
        }

        val header = rows[headerIndex].map { normalizeHeader(it) }
        fun col(vararg names: String): Int? {
            names.forEach { name ->
                val index = header.indexOf(normalizeHeader(name))
                if (index >= 0) return index
            }
            return null
        }

        val firstIndex = col("First", "First Name", "FirstName")
        val lastIndex = col("Last", "Last Name", "LastName")
        val avgIndex = col("AVG", "BA", "Batting Average")
        val obpIndex = col("OBP", "On Base Percentage")
        val opsIndex = col("OPS")
        val slgIndex = col("SLG", "Slugging")
        val hitsIndex = col("H", "Hits")
        val rbiIndex = col("RBI", "RBIs")
        val runsIndex = col("R", "Runs")
        val walksIndex = col("BB", "Walks")
        val strikeoutsIndex = col("SO", "K", "Strikeouts")

        if (firstIndex == null || lastIndex == null) {
            gameChangerStatusMessage = "Import failed: missing First or Last columns."
            return
        }

        val imported = mutableMapOf<String, GameChangerStats>()
        rows.drop(headerIndex + 1).forEach { row ->
            if (row.size <= maxOf(firstIndex, lastIndex)) return@forEach
            val key = normalizePlayerName("${row[firstIndex]} ${row[lastIndex]}")
            if (key.isBlank()) return@forEach
            imported[key] = GameChangerStats(
                avg = csvValue(row, avgIndex),
                obp = csvValue(row, obpIndex),
                ops = csvValue(row, opsIndex),
                slg = csvValue(row, slgIndex),
                hits = csvValue(row, hitsIndex),
                rbi = csvValue(row, rbiIndex),
                runs = csvValue(row, runsIndex),
                walks = csvValue(row, walksIndex),
                strikeouts = csvValue(row, strikeoutsIndex)
            )
        }

        var matched = 0
        players.forEach { player ->
            imported[normalizePlayerName(player.name)]?.let { stats ->
                player.stats = stats
                matched += 1
            }
        }

        gameChangerStatusMessage = "Imported GameChanger stats for $matched player(s)."
    }

    fun importSelectedTeamJson(jsonText: String) {
        try {
            val trimmed = jsonText.trim()
            if (trimmed.isEmpty()) {
                backupStatusMessage = "Import failed: empty file."
                return
            }

            val root = JSONObject(trimmed)
            importTeamJson(selectedTeamIndex, root)
            showAssignedLineupTable = root.optBoolean("showAssignedLineupTable", showAssignedLineupTable)
            showBenchOnField = root.optBoolean("showBenchOnField", showBenchOnField)
            showFullNameAndNumber = root.optBoolean("showFullNameAndNumber", showFullNameAndNumber)
            showOnlyNineBattersAndDH = root.optBoolean("showOnlyNineBattersAndDH", showOnlyNineBattersAndDH)
            showRatingsOnField = root.optBoolean("showRatingsOnField", showRatingsOnField)
            showSlowSpeedBattingWarnings = root.optBoolean("showSlowSpeedBattingWarnings", showSlowSpeedBattingWarnings)
            backupStatusMessage = "Imported player data for $selectedTeamName."
        } catch (error: Exception) {
            backupStatusMessage = "Import failed: ${error.localizedMessage ?: "Invalid JSON"}"
        }
    }

    private fun csvValue(row: List<String>, index: Int?): String {
        if (index == null || index !in row.indices) return "—"
        return row[index].trim().ifEmpty { "—" }
    }

    private fun normalizeHeader(value: String): String =
        value.lowercase().replace(" ", "").replace("-", "").replace("_", "").trim()

    private fun normalizePlayerName(value: String): String =
        value.lowercase().split(Regex("[^a-z0-9]+")) .filter { it.isNotBlank() }.joinToString(" ")

    private fun buildTeamJson(index: Int): JSONObject {
        return JSONObject().apply {
            put("teamName", teamNames[index])
            put("selectedInning", teamSelectedInnings[index])
            put("players", JSONArray().also { array ->
                teamPlayers[index].forEach { player ->
                    array.put(playerToJson(player))
                }
            })
            put("battingOrderIds", JSONArray().also { array ->
                teamBattingOrders[index].forEach { id -> array.put(id) }
            })
            put("lineup", lineupToJson(teamLineups[index]))
            put("inningLineups", JSONObject().also { innings ->
                teamInningLineups[index].forEach { (inning, lineup) ->
                    innings.put(inning.toString(), lineupToJson(lineup))
                }
            })
            put("inningPitcherIDs", JSONObject().also { pitchers ->
                teamInningPitcherIds[index].forEach { (inning, playerId) -> pitchers.put(inning.toString(), playerId) }
            })
            put("inningCatcherIDs", JSONObject().also { catchers ->
                teamInningCatcherIds[index].forEach { (inning, playerId) -> catchers.put(inning.toString(), playerId) }
            })
        }
    }

    private fun importTeamJson(index: Int, root: JSONObject) {
        teamNames[index] = root.optString("teamName", teamNames[index])
        teamSelectedInnings[index] = root.optInt("selectedInning", 1).coerceIn(1, 7)

        teamPlayers[index].clear()
        val playerMap = mutableMapOf<String, Player>()
        root.optJSONArray("players")?.let { playersArray ->
            for (i in 0 until playersArray.length()) {
                val player = playerFromJson(playersArray.getJSONObject(i))
                teamPlayers[index].add(player)
                playerMap[player.id] = player
            }
        }

        teamBattingOrders[index].clear()
        val battingOrderArray = root.optJSONArray("battingOrderIds") ?: root.optJSONArray("battingOrderIDs")
        battingOrderArray?.let { orderArray ->
            for (i in 0 until orderArray.length()) {
                val id = orderArray.optString(i)
                if (playerMap.containsKey(id)) teamBattingOrders[index].add(id)
            }
        }
        teamPlayers[index].forEach { player ->
            if (!teamBattingOrders[index].contains(player.id)) teamBattingOrders[index].add(player.id)
        }

        teamLineups[index].clear()
        teamLineups[index].putAll(lineupFromJson(root.opt("lineup"), playerMap))

        teamInningLineups[index].clear()
        root.optJSONObject("inningLineups")?.let { innings ->
            innings.keys().forEach { key ->
                key.toIntOrNull()?.let { inning ->
                    teamInningLineups[index][inning] = mutableStateMapOf<FieldPosition, Player>().also {
                        it.putAll(lineupFromJson(innings.opt(key), playerMap))
                    }
                }
            }
        }

        teamInningPitcherIds[index].clear()
        root.optJSONObject("inningPitcherIDs")?.let { pitchers ->
            pitchers.keys().forEach { key ->
                val id = pitchers.optString(key)
                if (key.toIntOrNull() != null && playerMap.containsKey(id)) {
                    teamInningPitcherIds[index][key.toInt()] = id
                    teamInningLineups[index].getOrPut(key.toInt()) { mutableStateMapOf() }[FieldPosition.Pitcher] = playerMap.getValue(id)
                }
            }
        }

        teamInningCatcherIds[index].clear()
        root.optJSONObject("inningCatcherIDs")?.let { catchers ->
            catchers.keys().forEach { key ->
                val id = catchers.optString(key)
                if (key.toIntOrNull() != null && playerMap.containsKey(id)) {
                    teamInningCatcherIds[index][key.toInt()] = id
                    teamInningLineups[index].getOrPut(key.toInt()) { mutableStateMapOf() }[FieldPosition.Catcher] = playerMap.getValue(id)
                }
            }
        }

        if (selectedTeamIndex == index) {
            teamLineups[index].clear()
            teamLineups[index].putAll(
                teamInningLineups[index][teamSelectedInnings[index]]
                    ?: lineupFromJson(root.opt("lineup"), playerMap)
            )
        }
    }

    private fun playerToJson(player: Player): JSONObject {
        return JSONObject().apply {
            put("id", player.id)
            put("name", player.name)
            put("number", player.number)
            put("stealRating", player.stealRating)
            put("status", player.status.name)
            put("positionRatings", JSONObject().also { ratings ->
                player.positionRatings.forEach { (position, rating) -> ratings.put(position.name, rating) }
            })
            player.stats?.let { stats ->
                put("stats", JSONObject().apply {
                    put("avg", stats.avg)
                    put("obp", stats.obp)
                    put("ops", stats.ops)
                    put("slg", stats.slg)
                    put("hits", stats.hits)
                    put("rbi", stats.rbi)
                    put("runs", stats.runs)
                    put("walks", stats.walks)
                    put("strikeouts", stats.strikeouts)
                })
            }
        }
    }

    private fun playerFromJson(root: JSONObject): Player {
        val player = Player(
            id = root.optString("id", UUID.randomUUID().toString()),
            name = root.optString("name", "Player"),
            number = root.optString("number", ""),
            stealRating = root.optInt("stealRating", root.optInt("speedRating", 1)),
            status = runCatching { PlayerStatus.valueOf(root.optString("status", "Active")) }.getOrDefault(PlayerStatus.Active)
        )

        readPositionRatings(root.opt("positionRatings"), player.positionRatings)

        root.optJSONObject("stats")?.let { stats ->
            player.stats = GameChangerStats(
                avg = stats.optString("avg", "—"),
                obp = stats.optString("obp", "—"),
                ops = stats.optString("ops", "—"),
                slg = stats.optString("slg", "—"),
                hits = stats.optString("hits", "—"),
                rbi = stats.optString("rbi", "—"),
                runs = stats.optString("runs", "—"),
                walks = stats.optString("walks", "—"),
                strikeouts = stats.optString("strikeouts", "—")
            )
        }

        return player
    }

    private fun lineupToJson(lineup: Map<FieldPosition, Player>): JSONObject {
        return JSONObject().apply {
            lineup.forEach { (position, player) -> put(position.name, player.id) }
        }
    }

    private fun lineupFromJson(root: Any?, playersById: Map<String, Player>): MutableMap<FieldPosition, Player> {
        val lineup = mutableStateMapOf<FieldPosition, Player>()
        when (root) {
            is JSONObject -> {
                root.keys().forEach { key ->
                    val position = fieldPositionFromJsonKey(key) ?: return@forEach
                    val value = root.opt(key)
                    val player = when (value) {
                        is JSONObject -> playerFromJson(value)
                        else -> playersById[root.optString(key)]
                    }
                    if (player != null) lineup[position] = playersById[player.id] ?: player
                }
            }
            is JSONArray -> {
                var i = 0
                while (i < root.length() - 1) {
                    val position = fieldPositionFromJsonKey(root.optString(i))
                    val playerObject = root.optJSONObject(i + 1)
                    if (position != null && playerObject != null) {
                        val importedPlayer = playerFromJson(playerObject)
                        val player = playersById[importedPlayer.id] ?: importedPlayer
                        lineup[position] = player
                    }
                    i += 2
                }
            }
        }
        return lineup
    }

    private fun readPositionRatings(value: Any?, target: MutableMap<FieldPosition, Int>) {
        when (value) {
            is JSONObject -> {
                value.keys().forEach { key ->
                    val position = fieldPositionFromJsonKey(key) ?: return@forEach
                    target[position] = value.optInt(key)
                }
            }
            is JSONArray -> {
                var i = 0
                while (i < value.length() - 1) {
                    val position = fieldPositionFromJsonKey(value.optString(i))
                    val rating = value.optInt(i + 1, -1)
                    if (position != null && rating > 0) {
                        target[position] = rating
                    }
                    i += 2
                }
            }
        }
    }

    private fun fieldPositionFromJsonKey(key: String): FieldPosition? {
        return when (key.trim().uppercase()) {
            "P", "PITCHER" -> FieldPosition.Pitcher
            "C", "CATCHER" -> FieldPosition.Catcher
            "1B", "1ST", "FIRSTBASE", "FIRST_BASE" -> FieldPosition.FirstBase
            "2B", "2ND", "SECONDBASE", "SECOND_BASE" -> FieldPosition.SecondBase
            "3B", "3RD", "THIRDBASE", "THIRD_BASE" -> FieldPosition.ThirdBase
            "SS", "SHORTSTOP" -> FieldPosition.Shortstop
            "LF", "LEFTFIELD", "LEFT_FIELD" -> FieldPosition.LeftField
            "CF", "CENTERFIELD", "CENTER_FIELD" -> FieldPosition.CenterField
            "RF", "RIGHTFIELD", "RIGHT_FIELD" -> FieldPosition.RightField
            else -> runCatching { FieldPosition.valueOf(key) }.getOrNull()
        }
    }

    private fun parseCsv(text: String): List<List<String>> {
        val rows = mutableListOf<MutableList<String>>()
        var row = mutableListOf<String>()
        val field = StringBuilder()
        var insideQuotes = false
        var i = 0
        while (i < text.length) {
            val c = text[i]
            when {
                c == '"' && insideQuotes && i + 1 < text.length && text[i + 1] == '"' -> {
                    field.append('"')
                    i++
                }
                c == '"' -> insideQuotes = !insideQuotes
                c == ',' && !insideQuotes -> {
                    row.add(field.toString())
                    field.clear()
                }
                c == '\n' && !insideQuotes -> {
                    row.add(field.toString())
                    rows.add(row)
                    row = mutableListOf()
                    field.clear()
                }
                c != '\r' -> field.append(c)
            }
            i++
        }
        row.add(field.toString())
        rows.add(row)
        return rows
    }

    private fun saveCurrentInningState() {
        teamInningLineups[selectedTeamIndex][selectedInning] = mutableStateMapOf<FieldPosition, Player>().also {
            it.putAll(teamLineups[selectedTeamIndex])
        }
        lineup[FieldPosition.Pitcher]?.let { teamInningPitcherIds[selectedTeamIndex][selectedInning] = it.id }
        lineup[FieldPosition.Catcher]?.let { teamInningCatcherIds[selectedTeamIndex][selectedInning] = it.id }
    }

    private fun copyCurrentInningForwardIfNeeded() {
        if (selectedInning >= 7) return
        val pitcherId = selectedPitcher?.id
        val catcherId = selectedCatcher?.id
        for (inning in (selectedInning + 1)..7) {
            if (teamInningLineups[selectedTeamIndex][inning].isNullOrEmpty()) {
                teamInningLineups[selectedTeamIndex][inning] = mutableStateMapOf<FieldPosition, Player>().also {
                    it.putAll(teamLineups[selectedTeamIndex])
                }
                if (pitcherId != null) teamInningPitcherIds[selectedTeamIndex][inning] = pitcherId
                if (catcherId != null) teamInningCatcherIds[selectedTeamIndex][inning] = catcherId
            }
        }
    }

    fun setPitcherForCurrentInning(player: Player?) {
        if (player == null) {
            teamInningPitcherIds[selectedTeamIndex].remove(selectedInning)
            teamLineups[selectedTeamIndex].remove(FieldPosition.Pitcher)
        } else {
            teamInningPitcherIds[selectedTeamIndex][selectedInning] = player.id
            teamLineups[selectedTeamIndex][FieldPosition.Pitcher] = player
        }
        saveCurrentInningState()
        copyCurrentInningForwardIfNeeded()
    }

    fun setCatcherForCurrentInning(player: Player?) {
        if (player == null) {
            teamInningCatcherIds[selectedTeamIndex].remove(selectedInning)
            teamLineups[selectedTeamIndex].remove(FieldPosition.Catcher)
        } else {
            teamInningCatcherIds[selectedTeamIndex][selectedInning] = player.id
            teamLineups[selectedTeamIndex][FieldPosition.Catcher] = player
        }
        saveCurrentInningState()
        copyCurrentInningForwardIfNeeded()
    }

    private fun playerById(id: String?): Player? {
        if (id.isNullOrBlank()) return null
        return players.firstOrNull { it.id == id }
    }
}

enum class AppTab { Field, Lineup, Players, Settings }

@Composable
fun YouthBaseballAIApp(viewModel: LineupViewModel = remember { LineupViewModel() }) {
    var selectedTab by remember { mutableStateOf(AppTab.Field) }

    Scaffold(
        modifier = Modifier.fillMaxSize(),
        bottomBar = {
            NavigationBar {
                NavigationBarItem(
                    selected = selectedTab == AppTab.Field,
                    onClick = { selectedTab = AppTab.Field },
                    icon = { Text("F") },
                    label = { Text("Field") }
                )
                NavigationBarItem(
                    selected = selectedTab == AppTab.Lineup,
                    onClick = { selectedTab = AppTab.Lineup },
                    icon = { Text("L") },
                    label = { Text("Lineup") }
                )
                NavigationBarItem(
                    selected = selectedTab == AppTab.Players,
                    onClick = { selectedTab = AppTab.Players },
                    icon = { Text("P") },
                    label = { Text("Players") }
                )
                NavigationBarItem(
                    selected = selectedTab == AppTab.Settings,
                    onClick = { selectedTab = AppTab.Settings },
                    icon = { Text("S") },
                    label = { Text("Settings") }
                )
            }
        }
    ) { padding ->
        Box(Modifier.padding(padding)) {
            when (selectedTab) {
                AppTab.Field -> FieldScreen(viewModel)
                AppTab.Lineup -> LineupScreen(viewModel)
                AppTab.Players -> PlayersScreen(viewModel)
                AppTab.Settings -> SettingsScreen(viewModel)
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TeamSelector(viewModel: LineupViewModel) {
    SingleChoiceSegmentedButtonRow(Modifier.fillMaxWidth()) {
        viewModel.teamNames.forEachIndexed { index, name ->
            SegmentedButton(
                selected = viewModel.selectedTeamIndex == index,
                onClick = { viewModel.selectTeam(index) },
                shape = SegmentedButtonDefaults.itemShape(index = index, count = viewModel.teamNames.size)
            ) {
                Text(name)
            }
        }
    }
}

@Composable
fun ScreenCard(title: String, content: @Composable ColumnScope.() -> Unit) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .padding(12.dp)
    ) {
        Column(
            modifier = Modifier.padding(12.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Text(title, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
            content()
        }
    }
}

@Composable
fun BaseballFieldView(viewModel: LineupViewModel) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(430.dp)
            .background(Color(0xFF1F7A36), RoundedCornerShape(18.dp))
    ) {
        Canvas(modifier = Modifier.fillMaxSize()) {
            val w = size.width
            val h = size.height

            val outfield = Path().apply {
                moveTo(w * 0.05f, h * 0.58f)
                quadraticBezierTo(w * 0.50f, h * -0.02f, w * 0.95f, h * 0.58f)
                lineTo(w * 0.50f, h * 0.92f)
                close()
            }
            drawPath(outfield, Color(0xFF2FA64A))

            val infield = Path().apply {
                moveTo(w * 0.50f, h * 0.82f)
                lineTo(w * 0.75f, h * 0.60f)
                quadraticBezierTo(w * 0.65f, h * 0.45f, w * 0.50f, h * 0.40f)
                quadraticBezierTo(w * 0.35f, h * 0.45f, w * 0.25f, h * 0.60f)
                close()
            }
            drawPath(infield, Color(0xFFC28A45))

            val diamond = Path().apply {
                moveTo(w * 0.50f, h * 0.82f)
                lineTo(w * 0.75f, h * 0.60f)
                lineTo(w * 0.50f, h * 0.40f)
                lineTo(w * 0.25f, h * 0.60f)
                close()
            }
            drawPath(diamond, Color.White, style = Stroke(width = 4f))
        }

        FieldMarker(viewModel, FieldPosition.CenterField, 0.50f, 0.12f)
        FieldMarker(viewModel, FieldPosition.LeftField, 0.18f, 0.30f)
        FieldMarker(viewModel, FieldPosition.RightField, 0.80f, 0.30f)
        FieldMarker(viewModel, FieldPosition.Shortstop, 0.34f, 0.47f)
        FieldMarker(viewModel, FieldPosition.SecondBase, 0.63f, 0.47f)
        FieldMarker(viewModel, FieldPosition.ThirdBase, 0.22f, 0.63f)
        FieldMarker(viewModel, FieldPosition.FirstBase, 0.73f, 0.63f)
        FieldMarker(viewModel, FieldPosition.Pitcher, 0.49f, 0.64f)
        FieldMarker(viewModel, FieldPosition.Catcher, 0.49f, 0.86f)
    }
}

@Composable
fun BoxScope.FieldMarker(viewModel: LineupViewModel, position: FieldPosition, x: Float, y: Float) {
    val player = viewModel.lineup[position]
    val rating = player?.positionRatings?.get(position)

    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        modifier = Modifier
            .offset(x = (x * 320).dp, y = (y * 390).dp)
            .width(96.dp)
    ) {
        Text(
            position.label,
            color = Color.White,
            fontWeight = FontWeight.Bold,
            modifier = Modifier
                .background(Color(0xDD0A5F25), RoundedCornerShape(20.dp))
                .padding(horizontal = 8.dp, vertical = 3.dp)
        )
        Text(
            player?.let { viewModel.displayLabel(it) } ?: "—",
            color = Color.Black,
            modifier = Modifier
                .background(Color.White, RoundedCornerShape(6.dp))
                .padding(horizontal = 5.dp, vertical = 3.dp)
        )
        if (viewModel.showRatingsOnField && rating != null) {
            Text(
                "R$rating",
                color = Color.Black,
                modifier = Modifier
                    .background(Color.White, RoundedCornerShape(6.dp))
                    .padding(horizontal = 5.dp, vertical = 2.dp)
            )
        }
    }
}

@Composable
fun FieldScreen(viewModel: LineupViewModel) {
    LazyColumn(Modifier.fillMaxSize()) {
        item {
            ScreenCard("Team") {
                TeamSelector(viewModel)
                Text(viewModel.selectedTeamName, fontWeight = FontWeight.Bold)
            }
        }
        item {
            ScreenCard("Inning") {
                Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                    (1..7).forEach { inning ->
                        Button(onClick = { viewModel.selectInning(inning) }) {
                            Text(if (viewModel.selectedInning == inning) "[$inning]" else "$inning")
                        }
                    }
                }
            }
        }
        item {
            ScreenCard("Pitcher / Catcher") {
                PitcherCatcherSelector(viewModel, FieldPosition.Pitcher, viewModel.selectedPitcher) { player ->
                    viewModel.setPitcherForCurrentInning(player)
                }
                PitcherCatcherSelector(viewModel, FieldPosition.Catcher, viewModel.selectedCatcher) { player ->
                    viewModel.setCatcherForCurrentInning(player)
                }
            }
        }
        item {
            ScreenCard("Actions") {
                Button(onClick = { viewModel.autoFillLineup() }, modifier = Modifier.fillMaxWidth()) {
                    Text("Auto-Fill Remaining Positions")
                }
                Button(onClick = { viewModel.clearInning() }, modifier = Modifier.fillMaxWidth()) {
                    Text("Clear Inning")
                }
                Button(onClick = { viewModel.clearAllInnings() }, modifier = Modifier.fillMaxWidth()) {
                    Text("Clear All Innings")
                }
                Button(onClick = { viewModel.setCurrentLineupForAllInnings() }, modifier = Modifier.fillMaxWidth()) {
                    Text("Set Lineup for All Innings")
                }
            }
        }
        item {
            ScreenCard("Field") {
                BaseballFieldView(viewModel)
            }
        }
        item {
            ScreenCard("Field Assignments") {
                FieldPosition.entries.forEach { position ->
                    PositionAssignmentDropdown(
                        viewModel = viewModel,
                        position = position,
                        selectedPlayer = viewModel.lineup[position],
                        onPlayerSelected = { player ->
                            if (player == null) {
                                when (position) {
                                    FieldPosition.Pitcher -> viewModel.setPitcherForCurrentInning(null)
                                    FieldPosition.Catcher -> viewModel.setCatcherForCurrentInning(null)
                                    else -> viewModel.clearPosition(position)
                                }
                            } else {
                                when (position) {
                                    FieldPosition.Pitcher -> viewModel.setPitcherForCurrentInning(player)
                                    FieldPosition.Catcher -> viewModel.setCatcherForCurrentInning(player)
                                    else -> viewModel.assignPosition(position, player)
                                }
                            }
                        }
                    )
                }
            }
        }
        if (viewModel.showBenchOnField) {
            item {
                ScreenCard("Bench") {
                    val bench = viewModel.benchPlayers()
                    if (bench.isEmpty()) {
                        Text("No bench players")
                    } else {
                        bench.forEach { player ->
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Text(viewModel.displayLabel(player), modifier = Modifier.weight(1f))
                                Button(onClick = { viewModel.placeBenchPlayerInField(player) }) {
                                    Text("Put In Field")
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PitcherCatcherSelector(
    viewModel: LineupViewModel,
    position: FieldPosition,
    selectedPlayer: Player?,
    onPlayerSelected: (Player?) -> Unit
) {
    var expanded by remember(position, selectedPlayer?.id) { mutableStateOf(false) }
    val selectedLabel = selectedPlayer?.let { viewModel.displayLabel(it) } ?: "Unassigned"

    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Text(position.label, fontWeight = FontWeight.Bold)
        ExposedDropdownMenuBox(
            expanded = expanded,
            onExpandedChange = { expanded = !expanded }
        ) {
            OutlinedTextField(
                value = selectedLabel,
                onValueChange = {},
                readOnly = true,
                label = { Text("Select ${position.label}") },
                trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = expanded) },
                modifier = Modifier
                    .menuAnchor()
                    .fillMaxWidth()
            )
            ExposedDropdownMenu(
                expanded = expanded,
                onDismissRequest = { expanded = false }
            ) {
                DropdownMenuItem(
                    text = { Text("Unassigned") },
                    onClick = {
                        onPlayerSelected(null)
                        expanded = false
                    }
                )
                viewModel.rankedPlayersForPosition(position).forEach { player ->
                    val rating = player.positionRatings[position]
                    val ratingText = if (rating != null) " — rating $rating" else " — no ${position.label} rating"
                    DropdownMenuItem(
                        text = { Text("${viewModel.displayLabel(player)}$ratingText") },
                        onClick = {
                            onPlayerSelected(player)
                            expanded = false
                        }
                    )
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PositionAssignmentDropdown(
    viewModel: LineupViewModel,
    position: FieldPosition,
    selectedPlayer: Player?,
    onPlayerSelected: (Player?) -> Unit
) {
    var expanded by remember(position, selectedPlayer?.id) { mutableStateOf(false) }
    val selectedLabel = selectedPlayer?.let { viewModel.displayLabel(it) } ?: "Unassigned"

    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        ExposedDropdownMenuBox(
            expanded = expanded,
            onExpandedChange = { expanded = !expanded }
        ) {
            OutlinedTextField(
                value = selectedLabel,
                onValueChange = {},
                readOnly = true,
                label = { Text(position.label) },
                trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = expanded) },
                modifier = Modifier
                    .menuAnchor()
                    .fillMaxWidth()
            )
            ExposedDropdownMenu(
                expanded = expanded,
                onDismissRequest = { expanded = false }
            ) {
                DropdownMenuItem(
                    text = { Text("Unassigned") },
                    onClick = {
                        onPlayerSelected(null)
                        expanded = false
                    }
                )
                viewModel.rankedPlayersForPosition(position).forEach { player ->
                    val rating = player.positionRatings[position]
                    val ratingText = if (rating != null) " — rating $rating" else " — no ${position.label} rating"
                    DropdownMenuItem(
                        text = { Text("${viewModel.displayLabel(player)}$ratingText") },
                        onClick = {
                            onPlayerSelected(player)
                            expanded = false
                        }
                    )
                }
            }
        }
    }
}

@Composable
fun LineupGridTable(viewModel: LineupViewModel) {
    val rows = viewModel.lineupGridRows()
    val scrollState = rememberScrollState()

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .horizontalScroll(scrollState)
    ) {
        rows.forEachIndexed { rowIndex, row ->
            Row(verticalAlignment = Alignment.CenterVertically) {
                row.forEachIndexed { columnIndex, cell ->
                    val width = when (columnIndex) {
                        0 -> 72.dp
                        1 -> 180.dp
                        else -> 56.dp
                    }
                    Text(
                        text = cell,
                        fontWeight = if (rowIndex == 0) FontWeight.Bold else FontWeight.Normal,
                        modifier = Modifier
                            .width(width)
                            .padding(6.dp)
                    )
                }
            }
        }
    }
}

@Composable
fun LineupScreen(viewModel: LineupViewModel) {
    viewModel.syncBattingOrder()
    val orderedPlayers = viewModel.battingOrderIds
        .mapNotNull { id -> viewModel.players.firstOrNull { it.id == id } }
        .filter { it.status == PlayerStatus.Active }
    val displayedPlayers = if (viewModel.showOnlyNineBattersAndDH) orderedPlayers.take(9) else orderedPlayers
    val context = LocalContext.current
    val saveLineupLauncher = rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("text/csv")) { uri ->
        if (uri != null) {
            context.contentResolver.openOutputStream(uri)?.bufferedWriter()?.use { writer ->
                writer.write(viewModel.lineupGridCsv())
            }
        }
    }

    LazyColumn(Modifier.fillMaxSize()) {
        item {
            ScreenCard("Team") {
                TeamSelector(viewModel)
                Text(viewModel.selectedTeamName, fontWeight = FontWeight.Bold)
            }
        }
        item {
            ScreenCard("Print / Save") {
                Button(onClick = {
                    val safeTeamName = viewModel.selectedTeamName
                        .replace(Regex("[^A-Za-z0-9_-]+"), "_")
                        .ifBlank { "Lineup" }
                    saveLineupLauncher.launch("${safeTeamName}_Lineup_Grid.csv")
                }, modifier = Modifier.fillMaxWidth()) {
                    Text("Save Lineup Grid")
                }
                Button(onClick = {
                    val intent = Intent(Intent.ACTION_SEND).apply {
                        type = "text/csv"
                        putExtra(Intent.EXTRA_TEXT, viewModel.lineupGridCsv())
                        putExtra(Intent.EXTRA_SUBJECT, "${viewModel.selectedTeamName} Lineup Grid")
                    }
                    context.startActivity(Intent.createChooser(intent, "Share Lineup Grid"))
                }, modifier = Modifier.fillMaxWidth()) {
                    Text("Share Lineup Grid")
                }
            }
        }
        item {
            ScreenCard("Lineup Grid") {
                LineupGridTable(viewModel)
            }
        }
        item {
            ScreenCard("Batting Order") {
                if (displayedPlayers.isEmpty()) {
                    Text("Add players on the Players tab.")
                } else {
                    displayedPlayers.forEachIndexed { index, player ->
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text("${index + 1}.", modifier = Modifier.width(32.dp), fontWeight = FontWeight.Bold)
                            Column(Modifier.weight(1f)) {
                                Text(viewModel.displayLabel(player), fontWeight = FontWeight.Bold)
                                Text(if (player.stealRating == 1) "Steal" else "No Steal")
                                player.stats?.let { stats ->
                                    Text(stats.displayText(), fontStyle = androidx.compose.ui.text.font.FontStyle.Italic)
                                }
                            }
                            Button(onClick = { viewModel.moveBatter(index, -1) }) { Text("↑") }
                            Button(onClick = { viewModel.moveBatter(index, 1) }) { Text("↓") }
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun PlayersScreen(viewModel: LineupViewModel) {
    var newPlayerName by remember { mutableStateOf("") }

    LazyColumn(Modifier.fillMaxSize()) {
        item {
            ScreenCard("Team") {
                TeamSelector(viewModel)
                Text(viewModel.selectedTeamName, fontWeight = FontWeight.Bold)
            }
        }
        item {
            ScreenCard("Add Player") {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    OutlinedTextField(
                        value = newPlayerName,
                        onValueChange = { newPlayerName = it },
                        label = { Text("Player name") },
                        modifier = Modifier.weight(1f)
                    )
                    Spacer(Modifier.width(8.dp))
                    Button(onClick = {
                        viewModel.addPlayer(newPlayerName)
                        newPlayerName = ""
                    }) {
                        Text("Add")
                    }
                }
            }
        }
        items(viewModel.players, key = { it.id }) { player ->
            var isEditing by remember(player.id) { mutableStateOf(false) }

            Card(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 12.dp, vertical = 4.dp)
                    .clickable { isEditing = true }
            ) {
                Column(Modifier.padding(12.dp)) {
                    Text(viewModel.displayLabel(player), fontWeight = FontWeight.Bold)
                    if (player.status != PlayerStatus.Active) {
                        Text(if (player.status == PlayerStatus.Injured) "Injured" else "Unavailable")
                    }
                    val summary = FieldPosition.entries.mapNotNull { position ->
                        player.positionRatings[position]?.let { "${position.label}: $it" }
                    }.joinToString(" • ")
                    Text(if (summary.isBlank()) "No positions added" else summary)
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        Button(onClick = { isEditing = true }) { Text("Edit") }
                        Button(onClick = { viewModel.setPlayerStatus(player, PlayerStatus.Unavailable) }) { Text("Unavailable") }
                        Button(onClick = { viewModel.setPlayerStatus(player, PlayerStatus.Injured) }) { Text("Injured") }
                    }
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        if (player.status != PlayerStatus.Active) {
                            Button(onClick = { viewModel.setPlayerStatus(player, PlayerStatus.Active) }) { Text("Active") }
                        }
                        Button(onClick = { viewModel.deletePlayer(player) }) { Text("Delete") }
                    }
                }
            }

            if (isEditing) {
                PlayerEditDialog(viewModel, player) { isEditing = false }
            }
        }
    }
}

@Composable
fun PlayerEditDialog(viewModel: LineupViewModel, player: Player, onDismiss: () -> Unit) {
    var name by remember(player.id) { mutableStateOf(player.name) }
    var number by remember(player.id) { mutableStateOf(player.number) }
    var stealRating by remember(player.id) { mutableIntStateOf(player.stealRating) }
    var selectedPosition by remember { mutableStateOf(FieldPosition.Pitcher) }
    var selectedRating by remember { mutableIntStateOf(1) }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Edit Player") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedTextField(value = name, onValueChange = { name = it }, label = { Text("Name") })
                OutlinedTextField(value = number, onValueChange = { number = it }, label = { Text("Number") })
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Button(onClick = { stealRating = 1 }) { Text("Steal") }
                    Button(onClick = { stealRating = 2 }) { Text("No Steal") }
                }
                Text("Position Ratings", fontWeight = FontWeight.Bold)
                FieldPosition.entries.forEach { position ->
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(position.label, modifier = Modifier.width(48.dp))
                        (1..5).forEach { rating ->
                            Button(onClick = { viewModel.setRating(player, position, rating) }) {
                                Text("$rating")
                            }
                        }
                    }
                }
            }
        },
        confirmButton = {
            Button(onClick = {
                viewModel.updatePlayer(player, name, number, stealRating)
                onDismiss()
            }) { Text("Save") }
        },
        dismissButton = {
            Button(onClick = onDismiss) { Text("Close") }
        }
    )
}

@Composable
fun SettingsScreen(viewModel: LineupViewModel) {
    var editedTeamName by remember(viewModel.selectedTeamIndex) { mutableStateOf(viewModel.selectedTeamName) }

    val context = LocalContext.current
    fun readTextFromUri(uri: Uri): String {
        return context.contentResolver.openInputStream(uri)?.bufferedReader()?.use { it.readText() } ?: ""
    }

    val gameChangerImportLauncher = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri ->
        if (uri != null) {
            viewModel.importGameChangerCsv(readTextFromUri(uri))
        }
    }

    val playerDataImportLauncher = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri ->
        if (uri != null) {
            viewModel.importSelectedTeamJson(readTextFromUri(uri))
        }
    }

    LazyColumn(Modifier.fillMaxSize()) {
        item {
            ScreenCard("Team") {
                TeamSelector(viewModel)
                OutlinedTextField(
                    value = editedTeamName,
                    onValueChange = { editedTeamName = it },
                    label = { Text("Team name") },
                    modifier = Modifier.fillMaxWidth()
                )
                Button(onClick = { viewModel.renameSelectedTeam(editedTeamName) }) {
                    Text("Save Team Name")
                }
            }
        }
        item {
            ScreenCard("GameChanger") {
                Button(onClick = { gameChangerImportLauncher.launch("text/*") }) {
                    Text("Import GameChanger Stats")
                }
                Button(onClick = { viewModel.clearGameChangerStats() }) {
                    Text("Clear GameChanger Stats")
                }
                Text(viewModel.gameChangerStatusMessage)
            }
        }
        item {
            ScreenCard("Backup") {
                Button(onClick = {
                    val json = viewModel.exportSelectedTeamJson()
                    val intent = Intent(Intent.ACTION_SEND).apply {
                        type = "application/json"
                        putExtra(Intent.EXTRA_TEXT, json)
                        putExtra(Intent.EXTRA_SUBJECT, "${viewModel.selectedTeamName} Player Data")
                    }
                    context.startActivity(Intent.createChooser(intent, "Share Player Data"))
                }) {
                    Text("Share Player Data")
                }
                Button(onClick = { playerDataImportLauncher.launch("application/json") }) {
                    Text("Import Player Data")
                }
                Text(viewModel.backupStatusMessage)
            }
        }
        item {
            ScreenCard("Display Options") {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text("Show ratings on field", modifier = Modifier.weight(1f))
                    Switch(checked = viewModel.showRatingsOnField, onCheckedChange = { viewModel.showRatingsOnField = it })
                }
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text("Show bench on field", modifier = Modifier.weight(1f))
                    Switch(checked = viewModel.showBenchOnField, onCheckedChange = { viewModel.showBenchOnField = it })
                }
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text("First initial / last name", modifier = Modifier.weight(1f))
                    Switch(checked = !viewModel.showFullNameAndNumber, onCheckedChange = { viewModel.showFullNameAndNumber = !it })
                }
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text("Only first 9 batters", modifier = Modifier.weight(1f))
                    Switch(checked = viewModel.showOnlyNineBattersAndDH, onCheckedChange = { viewModel.showOnlyNineBattersAndDH = it })
                }
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text("Warn on slow speed batting order", modifier = Modifier.weight(1f))
                    Switch(checked = viewModel.showSlowSpeedBattingWarnings, onCheckedChange = { viewModel.showSlowSpeedBattingWarnings = it })
                }
            }
        }
    }
}

@Preview(showBackground = true)
@Composable
fun AppPreview() {
    YouthBaseballAITheme {
        YouthBaseballAIApp()
    }
}