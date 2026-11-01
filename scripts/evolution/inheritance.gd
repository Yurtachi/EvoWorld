extends RefCounted
## Asexual inheritance. Mutation parameters are fractions of each gene's range.
const Genes = preload("res://scripts/creature/genome.gd")

static func inherit(parent: Genes, parent_id: int, rng, rate: float, scale: float) -> Dictionary:
	var child := Genes.from_dict(parent.to_dict())
	child.id = 0
	child.parents = [parent_id]
	child.generation = parent.generation + 1
	var mutations: Array = []
	for gene in Genes.BOUNDS:
		if rate <= 0.0 or rng.between(0.0, 1.0) >= rate:
			continue
		var bounds: Array = Genes.BOUNDS[gene]
		var span: float = bounds[1] - bounds[0]
		# Bounded Gaussian: max absolute change = 3 sigma; clip at physical bounds.
		var delta: float = clampf(rng.gaussian(span * scale), -3.0 * span * scale, 3.0 * span * scale)
		child.set(gene, clampf(snappedf(float(parent.get(gene)) + delta, 0.000001), bounds[0], bounds[1]))
	child.bound_genes()
	for gene in Genes.BOUNDS:
		var actual := snappedf(float(child.get(gene)) - float(parent.get(gene)), 0.000001)
		if actual != 0.0:
			mutations.append({"gene": gene, "delta": actual})
	return {"genome": child, "mutations": mutations}
