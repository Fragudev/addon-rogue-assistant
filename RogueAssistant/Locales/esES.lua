local _, ns = ...

-- Used for esES and esMX clients.
ns.Locale.Register("esES", {
  ["app.name"] = "Rogue Assistant",
  ["app.schema_newer"] = "Los datos guardados son de una versión más reciente (esquema %d). "
    .. "El addon se desactiva para protegerlos.",
  ["cmd.later"] = "Estará disponible en una versión posterior.",
  ["cmd.unknown"] = "Comando desconocido '%s'.",
  ["cmd.error"] = "Error en /ras %s: %s",
  ["cmd.help.header"] = "Comandos:",
  ["cmd.help.root"] = "/ras              abre los ajustes (versión posterior)",
  ["cmd.help.help"] = "/ras help         esta ayuda",
  ["cmd.help.unlock"] = "/ras unlock       mueve el tracker y el botón de venenos (versión posterior)",
  ["cmd.help.lock"] = "/ras lock         bloquea el tracker y el botón de venenos (versión posterior)",
  ["cmd.help.debug"] = "/ras debug        diagnóstico (probe | bags | spells | auras | selftest)",
  ["cmd.debug.header"] = "Comandos de depuración:",
  ["cmd.debug.probe"] = "probe     comprueba todas las API del cliente que el addon puede usar",
  ["cmd.debug.bags"] = "bags      lista los objetos de las bolsas con sus identificadores",
  ["cmd.debug.spells"] = "spells    lista el libro de hechizos con los identificadores",
  ["cmd.debug.auras"] = "auras     lista tus beneficios y los perjuicios que aplicas al objetivo",
  ["cmd.debug.selftest"] = "selftest  comprueba que existen las API del cliente de las que depende el addon",
  ["debug.bags.header"] = "Objetos en las bolsas: %d",
  ["debug.bags.empty"] = "No hay objetos legibles en las bolsas.",
  ["debug.spells.header"] = "Entradas del libro de hechizos: %d",
  ["debug.spells.empty"] = "No se puede leer el libro de hechizos.",
  ["debug.auras.player"] = "Beneficios del jugador (HELPFUL): %d",
  ["debug.auras.target"] = "Perjuicios tuyos en el objetivo (HARMFUL|PLAYER): %d",
  ["debug.auras.none"] = "No hay auras legibles.",
  ["debug.selftest.ok"] = "Las %d API del cliente necesarias están disponibles.",
  ["debug.selftest.missing"] = "API del cliente que faltan: %s",
  ["debug.probe.saved"] = "%d líneas de la sonda guardadas en RogueAssistantDB.debug.lastProbe.",
})
