#---------------------
# CODE INFO
# author: Flore Verbist 
# description: this code is used for the paper entitled "Unravelling CO2 value chain participation under negative emission pricing and industry relocation"


# To restart the Julia kernel in Visual Studio Code (VSC), you can use the built-in command palette:

# Press Ctrl + Shift + P (Windows, Linux) or Cmd + Shift + P (macOS) to open the command palette.
# Type "Julia: Restart Julia Language Server" in the search bar and select the command when it appears.
# Wait for the kernel to restart.

#-------------------------
## MAIN FILE 
# Step 0: activating environment
using Pkg 
# Pkg.activate(@__DIR__) # @__DIR__ = directory this script is in
# Pkg.instantiate() # If a Manifest.toml file exist in the current project, download all the packages declared in that manifest. Else, resolve a set of feasible packages from the Project.toml files and install them.
# USE v1.10 of julia !

# Step 1: 
# A) input packages


##################################################################################################################################################
# if error in packages start removing them one by one - rm Package_name - and add them one by one or with , for the onese you are certain off. 
##################################################################################################################################################
using CSV, Dates, Statistics, DataFrames, XLSX, Plots, StatsPlots, LaTeXStrings, Vega, NumericIO, Combinatorics, JLD2, FileIO, DataStructures, Distances, Shapefile
using Geodesy, GeoInterface, GeoDataFrames, OrderedCollections, ReverseGeocode, StaticArrays, PiecewiseLinearOpt, Interpolations, Optim, Random, Clustering
using  Graphs, Proj4  # Ensuring no stand alone pipelines
using GMT # https://discourse.julialang.org/t/errors-associated-with-using-gmt/70393 # might have problems with ReverseGeocode actually
using JuMP, Gurobi # https://discourse.julialang.org/t/gurobi-failed-to-precompile/44606/8
using Plots; LaTeXStrings;  pgfplotsx()
using GeometryBasics    # This package might also cause the error interdependency with Adapt --> AdaptStaticArraysExt
using Polynomials # might have an issue with JuMP
# note that if Gurobi stops working this might be caused by a downgrade the Gurobi_jll, and causes the Adapt --> AdaptStaticArraysExt to fail, and also dependencies of gurobi


# B) input function files attached to the main file 
include("import.jl")        # prerocessing of excel data
include("optimisation.jl")  # optimisation script
include("results.jl")       # results processing
include("visualisation.jl") # visualisation in julia
include("visualisation_python.jl") # visualisation in python
include("data_processing.jl")  # dataprocessing


# C) Parameters scenario 
# C.1) ########################## Selection of case parameters ##########################
Scenario_name = "CDR_price"     # Selection options: #  CDR_price # No_CDR_price # Exit # Exit_no_CDR
Scenario_horizon = 2050         # Optimisation year (currently only applicable to 2050)
Region = "Trilateral"           # Selection options: # Europe # Trilateral

Pieces = 1                      # Pipeline piecewise costs: 1 piece: linear function, 2 pieces, more concave fitting
Intercept = true                # True: binary variables for pipeline investments, false: no binary parameters for pipeline investments  

CO2_tax = 150                   # Emission Trading price EUR/tCO2 
detail_level = "coarse"         #Selection options for candidate grid detail: dense #coarse

Social_decision = true          # true: cc_emitters = variable, false: cc_emitters = parameter
Tariff = false                  # true: emitters are imposed by a max tariff level, false: emitters do not receive a predefined tariff level
MPEC = false                    # true: profit maximisation model, false: system optimal optimisation model 
# C.2) ################## parameters underlying scenario data (only used first time preprocessing) ##################
system_data_file =   eval(Symbol("system_data_file_", detail_level))        # System input data 
# C.3) ############ parameters sensitivity analysis/multi-run analysis ###########
HPC = false
CO2_tax_vect = [0, 25, 50, 100, 150, 175, 200, 250, 300, 350]
Scenario_horizon_vect = [2050]
Scenario_name_vect = ["No_CDR_price", "CDR_price",  "Exit_no_CDR", "Exit"] # "No_Bio"
Scenario_title_vect = ["CDR price", "No CDR price", "No Biomass", "EU Exit (CDR)", "EU Exit (no CDR)"]
tariff_vector = [6.29, 27.5, 10.97,  96.15]
tariff = tariff_vector[2]
Range_opt = [0,300]
Samples = 100

 
# D) ##################################  Case runs   ########################################

Costs, Routing_nodes_all, Pipelines_all, Terminals, Storage_offshore, Storage_inland, Offshore_nodes, Clusters = import_data_TandS(system_data_file)


k = 0
for SN in Scenario_name_vect
    k = k + 1
    for SH in Scenario_horizon_vect

        global Scenario_name = SN
        global Scenario_horizon = SH
        # Loading the correct parameters 
        global Figure_name = "$(Scenario_name)_$(Region)_$(detail_level)"
        Emitters = import_data_industry(CO2_tax::Any, Scenario_name::String, Scenario_horizon::Int64) #, (load_data=true; load_data))

        include("parameters.jl")    # run all the parameters of the script
        Max_total_connections = count(!iszero,values(TOT_capture_1_CO2))
        # preOpt_visualisation_py(shapefile_eu)
        model_1 = 0
        print(Figure_name)
        print("")
        model_1 = Model(optimizer_with_attributes(Gurobi.Optimizer,  "DualReductions" => 0, "TimeLimit" => 500, "MIPFocus" => 2)) #"OutputFlag" =>0 # "DualReductions" => 0 allows to find out if model is infeasable or unbounded
        #  "FeasibilityTol" => 1e-8, "OptimalityTol" => 1e-3
        global model_1 = initiate_optimal_coordination_model(model_1, Social_decision, Tariff, Intercept, (Initialization = false; Initialization))
        optimize!(model_1)
        global gap = MOI.get(model_1, MOI.RelativeGap())
        print(gap)
        parameters_extract(model_1)
        variables_extract(model_1)

        # extracting_start_solution(model_1, Scenario_name, detail_level, Pieces)
        Pipes_opt_co_na, Pipes_opt_sizes = opt_result_extracting4visualisation(model_1); # suppress output because prettytables doesn't work well 
        industrial_results_save(model_1, results_industry_file::String)
        Key_output_df = key_results_save(model_1, detail_level, results_stats_file, results_industry_file, scenario_file)
        pipeline_results_save(results_pipes_file::String, Pipes_opt_co_na, Pipes_opt_sizes)
        Storages_output_df = storage_results_save(Scenario_name::String, Region::String, CO2_tax::Int64)
        visualisation_pipes(shapefile_eu, Figure_name, (title_plot = ""; title_plot))
        # TandS_fraction_cost_plot(model_1)
    end
end
# E)  ###################### External result extraction  ############################


# E.1) OPTIONAL: HPC merging into excel
HPC = true
Region = "Europe" # Trilateral # Europe
detail_level = "coarse" # coarse # dense
HPC_csv_output_data_to_excel(Scenario_name_vect, Region, CO2_tax, detail_level)

# E.2) Visualisation using output csv files  
CO2_tax = 150
Region = "Trilateral" 
Social_decision = false 
Tariff = false
detail_level = "coarse"
Scenario_name = Scenario_name_vect[(i=4;i)]
for (i, SN) in enumerate(Scenario_name_vect)
    global Scenario_name = SN
    global Emitters = import_data_industry(CO2_tax::Any, Scenario_name::String, Scenario_horizon::Int64) #, (load_data=true; load_data))
    include("parameters.jl")    # run all the parameters of the script
    Key_df_results = key_results_extract(results_stats_Trilateral_file_HPC::String, Scenario_name::String, Region::String, CO2_tax::Int64)
    storages_extract = storage_results_extract(Scenario_name::String, Region::String, CO2_tax::Int64)
    print(Key_df_results)
    visualisation_pipes(shapefile_eu, (Figure_name = "$(Scenario_name)_$(Region)_$(detail_level)"; Figure_name), (title_plot = ""; title_plot))
end

# E.3) Sankeys 
HPC = true
CO2_tax = 150
Region = "Trilateral"
Social_decision = true 
Tariff = false
detail_level = "coarse"
Scenario_name = Scenario_name_vect[1]
Emitters = import_data_industry(CO2_tax::Any, Scenario_name::String, Scenario_horizon::Int64) #, (load_data=true; load_data))
include("parameters.jl")    # run all the parameters of the script

All_key_results_df_Trilateral = HPC_result_extraction(results_pipes_Trilateral_file_HPC::String, results_stats_Trilateral_file_HPC::String, results_industry_Trilateral_file_HPC::String, Scenario_name_vect, Scenario_horizon_vect, CO2_tax, (plotting=false; plotting))
All_key_results_df_Trilateral[!,"MIPgap"]
All_key_results_df_Trilateral[!,"Average T&S costs"]
DF_sankey_Trilateral = sankey_3_scenario_change_py(results_industry_Trilateral_file_HPC, (Scenario_name_1 = "No_CDR_price"; Scenario_name_1), (Scenario_name_2 = "CDR_price"; Scenario_name_2), (Scenario_name_3 = "Exit"; Scenario_name_3), (Figure_name = "$(Region)_sankey_py"; Figure_name), (Plotting = true; Plotting))
DF_sankey_Trilateral = sankey_2_scenario_change_py(results_industry_Trilateral_file_HPC, (Scenario_name_1 = "CDR_price"; Scenario_name_1), (Scenario_name_2 = "Exit"; Scenario_name_2), (Figure_name = "$(Region)_sankey_py"; Figure_name), (Plotting = true; Plotting))
DF_sankey_Trilateral = sankey_2_scenario_change_py(results_industry_Trilateral_file_HPC, (Scenario_name_1 = "No_CDR_price"; Scenario_name_1), (Scenario_name_2 = "CDR_price"; Scenario_name_2), (Figure_name = "$(Region)_sankey_py"; Figure_name), (Plotting = true; Plotting))

# E.4) Cost fractions T&S 
 TandS_fraction_cost_plot((absolute = true; absolute))


# E.5) WtP curves 
HPC = true
CO2_tax = 150
Region = "Trilateral"
Social_decision = true 
Tariff = false
detail_level = "coarse"
Scenario_name = Scenario_name_vect[1]
Emitters = import_data_industry(CO2_tax::Any, Scenario_name::String, Scenario_horizon::Int64) #, (load_data=true; load_data))
include("parameters.jl")    # run all the parameters of the script
WtP_curve(Scenario_name)


# E.6) Pie Plots 
visualisation_capture_clusters(Scenario_name::String, (CDR_effect = false; CDR_effect), (Legend = false; Legend))

# E.7) Other results 
for Scenario_name in Scenario_name_vect
    Scenario_horizon = 2050
    costs_plots(Scenario_name::String, Scenario_horizon::Int64)
end
for Scenario_name in Scenario_name_vect
    Total_bio_scenario_twh = biomass_quantities(Scenario_name::String, Scenario_horizon::Int64,results_stats_file, scenario_file)
    print(Total_bio_scenario_twh)
end



# F) ######################### CHECKS ####################################

# DF_sankey = sankey_scenario_change_py(results_industry_file, (Scenario_name_1 = "No_CDR_price"; Scenario_name_1), (Scenario_name_2 = "No_Bio"; Scenario_name_2), (Figure_name = "sankey_NoCDR_bio_py"; Figure_name))
# DF_sankey_Trilateral[(DF_sankey_Trilateral[:, "Scenario_1"] .== "Fossil + CC") .&& (DF_sankey_Trilateral[:, "Scenario_2"] .== "Electric"), :]
# DF_sankey_Trilateral[(DF_sankey_Trilateral[:, "Scenario_1"] .== "Electric") .&& (DF_sankey_Trilateral[:, "Scenario_2"] .== "Fossil + CC"), :]
# DF_sankey_Trilateral[DF_sankey_Trilateral[:, "Emitter_id"] .== "E2447",:] # DF_sankey_Trilateral[DF_sankey_Trilateral[:, "Emitter_id"] .== "E2309",:]  # DF_sankey_Trilateral[DF_sankey_Trilateral[:, "Emitter_id"] .== "E1849",:] 
# Emitters[Emitters[:, "Emitter_id"] .== "E2445", :]
#Emitters[Emitters[:,"Cluster_julia"] .== Emitters[Emitters[:, "Emitter_id"] .== "E2574", "Cluster_julia"], :]
DF_sankey_Trilateral[(DF_sankey_Trilateral[:, "Scenario_1"] .== "Electric") .&& (DF_sankey_Trilateral[:, "Scenario_2"] .== "Fossil + CC"), :]


# Pipe size max
non_zero = filter(x -> x != 0, (value.(q_pipe_pos)[:,:]).data)
max_value, max_key = findmax(collect(Pipes_opt_sizes))
max_coordinate = collect(values(Pipes_opt_co_na))[max_key]
max_value_pipe_pos, max_key_pipe_pos = findmax(collect(value.(q_pipe_pos)[:,:].data))
# collect(keys(q_pipe_pos))[max_key_pipe_pos]
max_value_pipe_neg, max_key_pipe_neg = findmax(collect(value.(q_pipe_neg)[:,:].data))
collect(keys(q_pipe_pos))[max_key_pipe_pos]
# On Pipe pos, and Pipe neg 
error = 10^-5
bin_q_pos = [q > error ? 1 : 0 for q in (value.(q_pipe_pos)[:,:]).data]
bin_q_neg = [q > error ? 1 : 0 for q in (value.(q_pipe_neg)[:,:]).data]
bin_q_sum = bin_q_pos .+ bin_q_neg
indices_2 = findall(x -> x == 2, bin_q_sum)
value_at_1842 = collect((value.(q_pipe_pos)[:,:]).data)[1932]
value_at_1842 = collect((value.(q_pipe_neg)[:,:]).data)[1932]
# Mass flow opt diameter
maximum(mass_flow_to_diameter(Pipes_opt_sizes))


