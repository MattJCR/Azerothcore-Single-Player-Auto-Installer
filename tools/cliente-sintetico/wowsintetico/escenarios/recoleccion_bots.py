# SPDX-FileCopyrightText: 2026 The Azerothcore-Single-Player contributors
# SPDX-License-Identifier: AGPL-3.0-or-later
"""Los bots con Herbalismo o Minería recolectan (UPD-O, mod-playerbots #2539, `Playerbots.RpgStatusProbWeight.DoGather`).

Sin un jugador dentro no hay bots activos, así que el personaje de prueba entra, espera a que se pueblen
y susurra `rpg status` a cada bot de la lista `bots`. Un GM recibe de vuelta el estado de RPG del bot
(`TellRpgStatusAction`: «Status: DO_GATHER», «GO_GRIND», «WANDER_RANDOM»...). El caso cuenta cuántos están en
DO_GATHER en ese instante y deja el reparto completo en `datos.estados`.

Los nombres salen de SQL (el cliente no ve las habilidades de otros): bots conectados con Herbalismo (182)
o Minería (186), por ejemplo
`SELECT DISTINCT c.name FROM characters c JOIN character_skills s ON s.guid=c.guid AND s.skill IN (182,186)
 WHERE c.online=1 AND c.account IN (SELECT id FROM acore_auth.account WHERE username LIKE 'RNDBOT%') LIMIT 100`.
Es una fotografía de población: que en una pasada ninguno recolecte no prueba que no lo hagan (el estado dura
15 minutos y su peso es una probabilidad), por eso un 0 es AVISO y no FALLO.
"""
import re
import time

from ..catalogo import Parametro, caso
from . import PersonajeTemporal, asegurar_vivo

CHAT_MSG_WHISPER = 7
PATRON_ESTADO = re.compile(r"Status:\s*([A-Z_]+)")


@caso(id="bots-recoleccion", titulo="Bots con Herbalismo o Minería en estado de recolección (UPD-O)",
      descripcion=__doc__, etiquetas=("bots", "playerbots", "recoleccion", "personaje"),
      acciones=("conectar", "leer", "personaje", "gm"),
      parametros={"bots": Parametro(str, "", "nombres de bots recolectores conectados, separados por comas (ver descripción)"),
                  "calentamiento": Parametro(int, 240, "segundos de espera tras entrar, para que se pueblen los bots",
                                             minimo=0, maximo=900),
                  "espera": Parametro(int, 4, "segundos esperando la respuesta de cada bot", minimo=2, maximo=15),
                  "minimo": Parametro(int, 1, "bots en DO_GATHER para dar OK", minimo=0, maximo=100)},
      duracion_max=1500, en_todo=False, protege=("PLAN UPD-O (recolección de bots)", "mod-playerbots #2539"),
      control="directo",
      observa=("la respuesta de cada bot a `rpg status` susurrado por un GM (Status: ...)",),
      no_cubre=("que el bot llegue a coger un nodo: sólo ve el estado, no el botín",
                "bots que no estén conectados cuando se les susurra",
                "frecuencia real: es una fotografía de un instante y el estado depende de una probabilidad"))
def ejecutar(ctx):
    inf, sec, p = ctx.inf, "bots-recoleccion", ctx.p
    nombres = [n.strip() for n in p["bots"].split(",") if n.strip()]
    if not inf.comprobar(sec, bool(nombres), "se indicó al menos un bot en `bots`",
                         "sin nombres no hay a quién susurrar (consulta SQL en la descripción)", origen="entorno"):
        return
    m = ctx.nueva_sesion()
    with PersonajeTemporal(ctx, m, 1, 1, sec):
        ctx.anotar_servidor(m)
        asegurar_vivo(m)
        m.comando("go xyz -9464.0 64.0 56.0 0", 4)       # Villadorada: un sitio concurrido y con nodos
        m.bombear(max(1, p["calentamiento"]))
        estados, sin_respuesta = {}, []
        por_bot = {}
        for nombre in nombres:
            antes = len(m.chat)
            m.susurrar(nombre, "rpg status")
            fin = time.time() + p["espera"]
            respuesta = None
            while time.time() < fin and respuesta is None:
                m.bombear(0.4)
                for e in m.chat[antes:]:
                    mt = PATRON_ESTADO.search(e["texto"])
                    if e["tipo"] == CHAT_MSG_WHISPER and mt:
                        respuesta = mt.group(1)
                        break
            if respuesta is None:
                sin_respuesta.append(nombre)
            else:
                estados[respuesta] = estados.get(respuesta, 0) + 1
                por_bot[nombre] = respuesta
        inf.datos["estados"] = estados
        inf.datos["por_bot"] = por_bot
        inf.datos["sin_respuesta"] = sin_respuesta
        respondieron = len(por_bot)
        if not inf.comprobar(sec, respondieron > 0, "algún bot contesta al susurro `rpg status`",
                             "%d de %d respondieron (sin respuesta: %s)" % (respondieron, len(nombres), ", ".join(sin_respuesta[:8])),
                             esperado="> 0", observado=respondieron, estado_si_no="AVISO"):
            return
        recolectan = estados.get("DO_GATHER", 0)
        detalle = "; ".join("%s: %d" % (k, v) for k, v in sorted(estados.items(), key=lambda kv: -kv[1]))
        inf.comprobar(sec, recolectan >= p["minimo"], "bots en estado de recolección (DO_GATHER)",
                      "%d de %d que respondieron (%s)" % (recolectan, respondieron, detalle),
                      esperado=">= %d" % p["minimo"], observado=recolectan, estado_si_no="AVISO")
        inf.comprobar(sec, not m.errores_lectura, "paquetes del mundo leídos sin error",
                      "; ".join(m.errores_lectura[:3]), origen="cliente")
