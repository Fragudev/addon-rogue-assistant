local _, ns = ...

ns.Locale.Register("esES", {
  ["slot.16"] = "MP",
  ["slot.17"] = "MS",
  ["slot.16.long"] = "Mano principal",
  ["slot.17.long"] = "Mano secundaria",
  ["button.missing"] = "Falta",
  ["button.hint"] = "Clic: elige qué aplicar",
  ["button.unknown"] = "El cliente oculta ahora el encantamiento de esta arma.",
  ["flyout.empty"] = "No llevas nada en las bolsas que sirva para esta arma.",
  ["handle.text"] = "Arrastra para mover",

  ["msg.loaded"] = "Rogue Assistant cargado. Escribe /ras para ver la ayuda.",
  ["msg.combat"] = "No se puede en combate. Inténtalo cuando acabe el combate.",
  ["msg.unlocked"] = "Barra desbloqueada: arrastra el asa y escribe /ras lock.",
  ["msg.locked"] = "Barra bloqueada.",
  ["msg.reset"] = "La barra ha vuelto a su posición por defecto.",
  ["msg.warn"] = "El aviso se enciende por debajo de %d minutos.",
  ["msg.warn.usage"] = "Uso: /ras warn <minutos> (de 0 a %d; con 0 solo avisa cuando no hay nada aplicado).",
  ["msg.unknown"] = "Comando desconocido: %s",

  ["help.title"] = "Comandos de Rogue Assistant:",
  ["help.unlock"] = "/ras unlock - mover la barra",
  ["help.lock"] = "/ras lock - bloquear la barra",
  ["help.reset"] = "/ras reset - devolver la barra a su posición por defecto",
  ["help.warn"] = "/ras warn <minutos> - cuándo se enciende el aviso",
  ["help.debug"] = "/ras debug bags | weapon - muestra lo que dice el cliente",

  ["debug.bags.header"] = "Objetos de las bolsas (id x cantidad, nombre, tipo):",
  ["debug.bags.none"] = "No hay objetos en las bolsas.",
  ["debug.weapon.line"] = "%s: activo=%s, ms=%s, cargas=%s, enchantID=%s, itemID=%s",
  ["debug.weapon.none"] = "GetWeaponEnchantInfo no ha devuelto nada.",

  ["kind.poison"] = "veneno",
  ["kind.sharpening"] = "piedra de afilar",
  ["kind.weightstone"] = "piedra de peso",
  ["kind.oil"] = "aceite",
})
