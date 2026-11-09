# SPDX-FileCopyrightText: 2026 The Azerothcore-Single-Player contributors
# SPDX-License-Identifier: AGPL-3.0-or-later
"""mod-transmog: el Transfigurador cambia la apariencia de un arma equipada y se puede deshacer.

Personaje nuevo (humano guerrero). Equipa una espada de una mano, añade otra espada distinta a su
colección con el comando de GM (`.transmog add`), invoca al transfigurador con `.npc add 190010`,
recorre su menú como un jugador (ranura de la mano derecha → el aspecto nuevo, con el cuadro de
confirmación y su coste) y comprueba que el objeto visible cambia pero el equipado sigue siendo el
mismo; luego quita la transfiguración desde el mismo menú y comprueba que el aspecto vuelve. La
criatura de prueba se borra al terminar (regla 9 de AGENTS.md) y el personaje, también.
"""
import re
import struct

from .. import actualizaciones as upd
from ..catalogo import caso
from . import PersonajeTemporal, sin_colores

RAZA, CLASE = 1, 1
TRANSFIGURADOR = 190010                # mod-transmog: «Warpweaver»
ESPADA_EQUIPADA = 2074                 # Hoja corta sólida (poco común, sin nivel mínimo)
ESPADA_ASPECTO = 6504                  # Ala-hoja (rara, sin nivel mínimo)
RANURA_MANO_DERECHA = 15               # índice en PLAYER_VISIBLE_ITEM / EQUIPMENT_SLOT_MAINHAND
MOCHILA_BASE = 23
CMSG_AUTOEQUIP_ITEM = 0x10A


def _ranura_en_mochila(m, entry):
    for i, (lo, hi) in enumerate(m.objetos_bolsas()):
        guid = lo | (hi << 32)
        if guid and m.objetos.get(guid, {}).get("valores", {}).get(upd.OBJECT_FIELD_ENTRY) == entry:
            return MOCHILA_BASE + i
    return None


def _limpio(texto):
    """Quita los iconos |T…|t y los colores de un texto de menú."""
    return sin_colores(re.sub(r"\|T[^|]*\|t", "", texto)).strip()


def _opcion(opciones, *palabras):
    palabras = [p.lower() for p in palabras]
    return next((o for o in opciones if any(p in _limpio(o["texto"]).lower() for p in palabras)), None)


@caso(id="transmog", titulo="mod-transmog: cambiar y quitar el aspecto de un arma",
      descripcion="""
Humano guerrero nuevo con una espada equipada (2074). Se añade el aspecto de otra (6504) a su
colección con `.transmog add`, se coloca el Transfigurador (190010) y se recorre su menú como un
jugador: ranura de la mano derecha → el aspecto nuevo (con el cuadro de confirmación y su coste).
Comprueba que el objeto VISIBLE de la mano derecha pasa a ser 6504 mientras el equipado sigue
siendo 2074, que se cobra el precio anunciado en el cuadro de confirmación (el servidor lo escala
por el nivel del objeto) y que «Eliminar todas las transfiguraciones» devuelve el aspecto original.
No cubre las demás ranuras, los conjuntos guardados, la interfaz de vendedor ni el cobro en fichas.
""",
      etiquetas=("modulos", "transmog", "npc", "personaje"),
      acciones=("conectar", "leer", "personaje", "gm"), duracion_max=240,
      protege=("mod-transmog",), control="directo",
      observa=("SMSG_GOSSIP_MESSAGE del Transfigurador", "objeto visible de la mano derecha",
               "restos: criatura `.npc add` borrada"),
      no_cubre=("otras ranuras", "conjuntos guardados", "interfaz de vendedor", "cobro en fichas (`RequireToken`)",
                "persistencia tras relogin o reinicio"))
def ejecutar(ctx):
    inf, sec = ctx.inf, "transmog"
    m = ctx.nueva_sesion()
    creados = []                        # criaturas de prueba a borrar al salir
    with PersonajeTemporal(ctx, m, RAZA, CLASE, sec) as pj:
        ctx.anotar_servidor(m)
        try:
            m.comando("additem %d" % ESPADA_EQUIPADA, 1)
            ranura = _ranura_en_mochila(m, ESPADA_EQUIPADA)
            if not inf.comprobar(sec, ranura is not None, "espada de partida en la mochila", origen="entorno"):
                return
            m.enviar(CMSG_AUTOEQUIP_ITEM, struct.pack("<BB", 255, ranura))
            m.bombear(1)
            visible = m.equipo_visible()[RANURA_MANO_DERECHA]
            if not inf.comprobar(sec, visible == ESPADA_EQUIPADA, "la espada de partida queda equipada",
                                 observado=visible, esperado=ESPADA_EQUIPADA, origen="entorno"):
                return

            # El coste sale del nivel del objeto (`ScaledCostModifier`): un personaje nuevo no
            # tiene dinero y el servidor rechaza el cambio sin avisar al menú.
            m.comando("modify money 1000000", 1)
            r = sin_colores(" ".join(m.comando("transmog add %d" % ESPADA_ASPECTO, 1.5)))
            inf.datos["transmog_add"] = r[:200]

            m.comando("gm on", 1)       # `.npc add` lo exige en este core
            antes = set(m.objetos.keys())
            m.comando("npc add %d" % TRANSFIGURADOR, 2)
            m.bombear(3)
            nuevos = [g for g in m.objetos if g not in antes
                      and m.objetos[g].get("typeid") == upd.TYPEID_UNIT
                      and m.objetos[g].get("valores", {}).get(upd.OBJECT_FIELD_ENTRY) == TRANSFIGURADOR]
            creados.extend(nuevos)
            if not inf.comprobar(sec, bool(nuevos), "el Transfigurador (190010) aparece junto al personaje"):
                return
            guid = nuevos[0]

            menu = m.conversar(guid)
            if not inf.comprobar(sec, menu is not None, "el Transfigurador abre su menú"):
                return
            menu_id, opciones = menu
            inf.datos["menu_principal"] = [_limpio(o["texto"]) for o in opciones]
            mano = _opcion(opciones, "main hand", "mano derecha", "mano principal")
            if not inf.comprobar(sec, mano is not None, "el menú ofrece la ranura de la mano derecha",
                                 "%d opciones" % len(opciones)):
                return

            lista = m.elegir(guid, menu_id, mano["id"])
            if not inf.comprobar(sec, lista is not None, "la ranura abre la lista de aspectos disponibles"):
                return
            menu_id, opciones = lista
            inf.datos["menu_ranura"] = [_limpio(o["texto"]) for o in opciones]
            aspecto = next((o for o in opciones if "item:%d" % ESPADA_ASPECTO in o["texto"]), None)
            if not inf.comprobar(sec, aspecto is not None,
                                 "la colección ofrece el aspecto añadido con `.transmog add`",
                                 "; ".join(inf.datos["menu_ranura"][:6])):
                return
            inf.comprobar(sec, bool(aspecto["confirmacion"]),
                          "pide confirmación antes de cobrar y aplicar", aspecto["confirmacion"][:80])
            inf.datos["coste_aspecto"] = aspecto["dinero"]

            dinero_antes = m.valor_propio(upd.PLAYER_FIELD_COINAGE)
            siguiente = m.elegir(guid, menu_id, aspecto["id"], timeout=3)
            inf.datos["tras_aplicar"] = [_limpio(o["texto"]) for o in siguiente[1]][:8] if siguiente else None
            m.bombear(4)
            visible = m.equipo_visible()[RANURA_MANO_DERECHA]
            inf.comprobar(sec, visible == ESPADA_ASPECTO, "el objeto visible pasa a ser el aspecto elegido",
                          observado=visible, esperado=ESPADA_ASPECTO)
            cobrado = dinero_antes - m.valor_propio(upd.PLAYER_FIELD_COINAGE)
            inf.comprobar(sec, cobrado == aspecto["dinero"], "cobra el coste anunciado en el cuadro de confirmación",
                          observado=cobrado, esperado=aspecto["dinero"])
            ranura_nueva = _ranura_en_mochila(m, ESPADA_EQUIPADA)
            inf.comprobar(sec, ranura_nueva is None,
                          "el arma equipada sigue siendo la original (no se pierde ni se duplica)")

            menu = m.conversar(guid)
            quitar = _opcion(menu[1], "remove all", "quitar todas", "eliminar todas",
                             "quitar las transfiguraciones", "remove transmog") if menu else None
            if not inf.comprobar(sec, quitar is not None,
                                 "el menú principal ofrece quitar las transfiguraciones",
                                 "; ".join(_limpio(o["texto"]) for o in (menu[1] if menu else [])[:12])):
                return
            m.elegir(guid, menu[0], quitar["id"], timeout=3)
            m.bombear(2)
            visible = m.equipo_visible()[RANURA_MANO_DERECHA]
            inf.comprobar(sec, visible == ESPADA_EQUIPADA, "al quitarla vuelve el aspecto original",
                          observado=visible, esperado=ESPADA_EQUIPADA)
            inf.comprobar(sec, not m.errores_lectura, "paquetes del mundo leídos sin error",
                          "; ".join(m.errores_lectura[:3]), origen="cliente")
        finally:
            for guid in creados:           # regla 9 de AGENTS.md: nada de pruebas en el mundo
                try:
                    m.comando("gm on", 0.5)
                    for _ in range(3):
                        m.seleccionar(guid)
                        m.bombear(1)
                        r = sin_colores(" ".join(m.comando("npc delete", 1.5)))
                        if "deleted" in r.lower() or "borrad" in r.lower() or "eliminad" in r.lower():
                            break
                except Exception as e:     # noqa: BLE001 — se anota y se sigue limpiando
                    inf.anotar(sec, "AVISO", "borrado del Transfigurador de prueba", repr(e))
