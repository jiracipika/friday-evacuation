# NVIDIA SimReady office chair

`models/overhaul/office_chair*.glb` adapt NVIDIA's
[`chair_office_fabric_manager_a01`](https://huggingface.co/datasets/nvidia/simready-assets/tree/4763fbfaa4f8e97658e68b57d01b4c86659e08b5/chair_office_fabric_manager_a01)
from the NVIDIA SimReady Assets collection. Copyright NVIDIA.

Licensed under [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/).
The original license is reproduced in `LICENSE.txt`. This attribution is also
shown in the game's Credits screen and included in desktop/browser packages.

Changes: flattened USD transforms; removed simulator payloads and original
textures; rebuilt three stylized materials; normalized scale/orientation;
reduced geometry to 5,498 triangles; generated 2,638- and 1,538-triangle LODs.
No endorsement by NVIDIA is implied.

The manifest records the immutable upstream revision and SHA-256 of each
downloaded source file. Reproduce with `tools/overhaul/fetch_nvidia_chair.py`
and the official Blender USD importer, then `tools/overhaul/build_assets.py`.
The other coworker, furniture, food and cosmetic chair meshes are authored
for this game by that Blender script.
