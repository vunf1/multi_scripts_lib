// List of required layer names
var requiredLayers = [
    "BENEDITENSE A", "BENEDITENSE B", "ALMADA 2015 B", "ALMADA 2015 A",
    "AD CAMACHA", "AD CCMI", "AD OEIRAS", "AD OEIRAS", "AD PEDRO ROMA",
    "AD PEDRO ROMA", "AF ALCOITÃO", "AF ALCOITÃO", "COSTIFOOT", "ANÇÃ FC",
    "AS SINTRA A", "AS SINTRA B", "AS SINTRA A", "AS SINTRA B", "AS SINTRA",
    "BENFICA EF", "BENFICA EF", "BENFICA EF", "CD 1º MAIO", "CD CN MAIA",
    "FEIRENSE A", "FEIRENSE B", "CD V. PINHEIRO", "CD V. PINHEIRO", "CF BENFICA",
    "SANTA IRIA", "SANTA IRIA", "CHARNECA CAP.", "CM FOOTBALL AC", "CM FOOTBALL AC",
    "CMF JANITAS", "CMF JANITAS", "PEDRO ARRUPE", "PEDRO ARRUPE", "PEDRO ARRUPE",
    "PINHEIROS", "PINHEIROS A", "PINHEIROS B", "FC PROBITY", "FC PROBITY",
    "FOOTESCOLA", "ATOUGUIENSE", "GD ESTORIL A", "GD ESTORIL B", "GD ESTORIL A",
    "GD ESTORIL B", "SOBREIRENSE A", "SOBREIRENSE B", "SANDINENSES", "GUIA FC",
    "CASTANHEIRA", "LEIXOES SC", "SÃO PAULO FC", "SÃO PAULO FC", "SC LOURINHA. A",
    "SC LOURINHA. B", "LOURINHANENSE", "SANJOANENSE", "CAMPELENSE", "SL BENFICA",
    "TEAM FC 6", "TEAM 6 FC A", "TEAM 6 FC B", "VILAFRANQUENSE", "UFC INDUSTRIA",
    "ULSAN IF", "VILANOVENSE", "AE ÓBIDOS", "ARECO/COTO", "ARECO/COTO A", "ARECO/COTO B",
    "CALDAS SC A", "CALDAS SC B", "CALDAS SC", "CALDAS SC", "CD EAF A", "CD EAF B",
    "CD EAF A", "CD EAF B", "CD EAF", "1º MAIO FC", "BENEDITENSE", "ACF PAULETA",
    "ACF PAULETA", "ACF PAULETA", "ALMADA 2015 A", "ALMADA 2015 B", "AD CAMACHA",
    "AD CAMACHA", "CARREGADO", "CARREGADO A", "CARREGADO B", "AD OEIRAS",
    "AD OERIAS", "QUINTA CONDE", "AD TAVRIA", "AD TAVIRA", "AF ALCOITÃO",
    "AF ALCOITÃO", "COSTIFOOT", "AS SINTRA", "AS SINTRA", "ATELTAS CRISTO",
    "BALLOAN CITY", "BALLOAN FURY", "BALLOAN FC", "ORIENTAL", "A-DOS-CUNHADOS",
    "CD V. PINHEIRO", "CHARNECA CAP.", "CM FOOTBALL AC", "PEDRO ARRUPE", "PEDRO ARRUPE",
    "PEDRO ARRUPE", "PEDRO ARRUPE", "SANTO AMÉRICO", "FOOTESCOLA", "GC TAVIRA",
    "ATOUGUIENSE", "ATOUGUIENSE", "SOBREIRENSE", "SANDINENSES A", "SANDINENSES B",
    "SANDINENESES", "CANICENSE", "MEM MARTINS", "SÃO PAULO FC", "LOURINHANENSE",
    "LOURINHANENSE", "SANJOANENSE", "SANTIAGO NORTE", "UD BATALHA", "UD SANTARÉM A",
    "UD SANTARÉM B", "UD SANTARÉM", "UR MERCÊS", "VILANOVENSE", "NADADOURO",
    "AE ÓBIDOS", "AE ÓBIDOS", "ARECO/COTO A", "ARECO/COTO B", "ARECO/COTO",
    "ARECO/COTO", "CALDAS SC A", "CALDAS SC B", "CD EAF", "CD EAF", "CD EAF"
];

// Function to get all layer names in a group, including nested layers
function getLayerNames(layerSet) {
    var layerNames = [];
    for (var i = 0; i < layerSet.artLayers.length; i++) {
        layerNames.push(layerSet.artLayers[i].name);
    }
    for (var j = 0; j < layerSet.layerSets.length; j++) {
        var nestedLayerSet = layerSet.layerSets[j];
        var nestedLayerNames = getLayerNames(nestedLayerSet);
        layerNames = layerNames.concat(nestedLayerNames);
    }
    return layerNames;
}

// Function to check for missing layers
function checkMissingLayers(groupName, subGroupName, layerNames) {
    var doc = app.activeDocument;
    var missingLayers = [];

    // Find the group
    var mainGroup;
    try {
        mainGroup = doc.layerSets.getByName(groupName);
    } catch (e) {
        alert("Group '" + groupName + "' not found.");
        return;
    }

    // Find the subgroup
    var subGroup;
    try {
        subGroup = mainGroup.layerSets.getByName(subGroupName);
    } catch (e) {
        alert("Subgroup '" + subGroupName + "' not found.");
        return;
    }

    // Get the names of all layers in the subgroup
    var existingLayers = getLayerNames(subGroup);

    // Check for missing layers
    for (var j = 0; j < layerNames.length; j++) {
        if (existingLayers.indexOf(layerNames[j]) === -1) {
            missingLayers.push(layerNames[j]);
        }
    }

    // Output missing layers
    if (missingLayers.length > 0) {
        alert("Missing layers:\n" + missingLayers.join("\n"));
    } else {
        alert("All layers are present.");
    }
}

// Execute the function to check for missing layers
checkMissingLayers("INTRO", "EQUIPA CASA", requiredLayers);
