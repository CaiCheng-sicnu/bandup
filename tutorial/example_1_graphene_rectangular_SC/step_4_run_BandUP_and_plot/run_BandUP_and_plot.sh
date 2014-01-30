#!/bin/bash

ulimit -s unlimited
export OMP_NUM_THREADS=8 # Choose 1 if you do not want openmp parallelization. I normally use n_cores/2
working_dir=`pwd`

bandup_folder="${HOME}/work/band_unfolding/BandUP" # Path to where BandUP is. Modify this line to suit your folder tree.
BandUp_exe=${bandup_folder}/BandUP_bin/BandUP.x
plot_script=${bandup_folder}/utils/post_unfolding/plot/plot_unfolded_EBS_BandUP.py
common_plot_folder=${working_dir}/plot
inputs_for_plot_folder="${working_dir}/input_files_plot"

sc_calc_folder="${working_dir}/../step_1_get_converged_CHGCAR"
band_calc_K_G_G_M_M_K_folder="${working_dir}/../step_3_get_SC_wavefunctions_to_be_used_for_unfolding/to_unfold_onto_pcbz_direc_K-G_G-M_M-K"
band_calc_perp_to_K_G_and_tc_K_folder="${working_dir}/../step_3_get_SC_wavefunctions_to_be_used_for_unfolding/to_unfold_onto_pcbz_direc_perp_to_K-G_and_touching_K"

E_Fermi_SC=`grep 'E-fermi' "${sc_calc_folder}/OUTCAR" | tail -1 | awk '{split($0,array," ")} END{print array[3]}'`
E_Fermi_K_G_G_M_M_K=`grep 'E-fermi' "${band_calc_K_G_G_M_M_K_folder}/OUTCAR" | tail -1 | awk '{split($0,array," ")} END{print array[3]}'`
E_Fermi_perp_to_K_G_and_touching_K=`grep 'E-fermi' "${band_calc_perp_to_K_G_and_tc_K_folder}/OUTCAR" | tail -1 | awk '{split($0,array," ")} END{print array[3]}'`
all_E_Fermis=($E_Fermi_SC $E_Fermi_K_G_G_M_M_K $E_Fermi_perp_to_K_G_and_touching_K)
IFS=$'\n'
E_Fermi=`echo "${all_E_Fermis[*]}" | sort -nr | head -n1`

dE=0.050


wavecar_calc_dir="${working_dir}/../step_3_get_SC_wavefunctions_to_be_used_for_unfolding"
pcbz_kpts_folder="${working_dir}/../step_2_get_kpts_to_be_used_in_the_SC_band_struc_calcs/input_files"
prim_cell_lattice_file_folder="${working_dir}/../step_2_get_kpts_to_be_used_in_the_SC_band_struc_calcs/input_files"
prim_cell_lattice_file="${prim_cell_lattice_file_folder}/prim_cell_lattice.in"

for dir in "K-G_G-M_M-K"  "perp_to_K-G_and_touching_K"
do
echo "Getting EBS along direction ${dir}..."
current_wavecar_folder="${wavecar_calc_dir}/to_unfold_onto_pcbz_direc_${dir}"
current_band_unfolding_folder="band_unfolding_onto_direc_${dir}"
KPOINTS_prim_cell_file=${pcbz_kpts_folder}/KPOINTS_prim_cell_${dir}.in

rm -rf ${current_band_unfolding_folder}
mkdir -p ${current_band_unfolding_folder}
cd ${current_band_unfolding_folder}

rm -f KPOINTS_prim_cell.in
cp $KPOINTS_prim_cell_file KPOINTS_prim_cell.in
rm -f prim_cell_lattice.in
cp $prim_cell_lattice_file prim_cell_lattice.in

if [ "$dir" == 'K-G_G-M_M-K' ]; then
    emin="-20.0"
    emax="  5.0"
else
    emin="-1.2"
    emax=" 1.2"
fi
cat >energy_info.in <<!
${E_Fermi} # E-fermi
${emin}
${emax}
${dE}
!

# Running BandUP
ln -s ${current_wavecar_folder}/WAVECAR WAVECAR
rm -f exe.x
ln -s $BandUp_exe exe.x
./exe.x | tee out_BandUP_dir_${dir}.dat 
rm -f exe.x

# Producing the plot
cat >"${inputs_for_plot_folder}"/energy_info_for_dir_${dir}.in <<!
${E_Fermi} # E-fermi
${emin}
${emax}
${dE}
!
plot_folder="${common_plot_folder}/direction_${dir}"
rm -rf ${plot_folder}
mkdir -p ${plot_folder}
cp unfolded_EBS_not-symmetry_averaged.dat ${plot_folder}
cp unfolded_EBS_symmetry-averaged.dat ${plot_folder}
cp "${inputs_for_plot_folder}"/energy_info_for_dir_${dir}.in ${plot_folder}/energy_info.in
cp "${inputs_for_plot_folder}"/KPOINTS_pcbz_${dir}.in ${plot_folder}/KPOINTS_prim_cell.in
cp "${inputs_for_plot_folder}"/prim_cell_lattice.in ${plot_folder}
ln -s ${plot_script} ${plot_folder}/plot_unfolded_EBS_BandUP.py

cd ${plot_folder}
    if [ "$dir" == 'K-G_G-M_M-K' ]; then
        ./plot_unfolded_EBS_BandUP.py unfolded_EBS_symmetry-averaged.dat -vmax 2 -vmin 0 --round_cb 0 --show --save &
    else
        ./plot_unfolded_EBS_BandUP.py unfolded_EBS_symmetry-averaged.dat -vmax 2 -vmin 0 --landscape --no_cb --show --save &
    fi
cd ${working_dir}

done

cd ${working_dir}