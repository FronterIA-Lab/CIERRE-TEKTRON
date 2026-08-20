# Estado — FREEZE (2026-08-20)

**No cerrar. No parchear. Recolectar contrato.**

Ver: **`REPLANTAMIENTO_CIERRE_RIGOR.md`**

## Por qué freeze

Tras reconcile: FAISS OK, polos normalizados a SITUADO, meta=Counter — y
`IndexL1` **sigue** en `assert len(set_sit)==meta["n_sit"]`.

Eso demuestra que el predicado de `set_sit` **no** es el Counter que asumimos.
Seguir con align-meta / restart es anti-arquitectura.

## Bloqueado

- reconcile --apply  
- align-meta  
- rebuild FAISS “por si acaso”  
- restart bridge como fix  

## Siguiente

Pegar en Jetson el bloque **Gate G0** de `REPLANTAMIENTO_CIERRE_RIGOR.md`
(sobre todo `sed -n '1,250p' /mnt/tektron/retrieve_l1.py`).
