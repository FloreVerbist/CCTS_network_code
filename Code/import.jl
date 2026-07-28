# Raw file 
raw_file = "./Raw input data files/AidRES_tables_dump.xlsx"
raw_file_gas_dense = "./Raw input data files/IGGIELGN/data/IGGIELGN_PipeSegments.csv"
raw_file_gas_coarse = "./Raw input data files/IGGIN/data/IGGIN_PipeSegments.csv"
raw_file_oil_terminals = "./Raw input data files/Oil terminals.csv"
raw_file_gas_terminals = "./Raw input data files/IGGIELGN/data/IGGIELGN_LNGs.csv"
EU_shape_file = "./Raw input data files/Europe/Europe_merged.shp"
raw_file_offshore_nodes = "./Raw input data files/Offshore_coordinates_europe.csv"
Project_user_interface_file = "./Raw input data files/user_interface.xlsx"
DCCI_file = "./Raw input data files/SP-Global-CI-Cost-Overall-Indexes-Overview-Q2-2024.xlsx"
USD_EUR_file = "./Raw input data files/USD_EUR Historical Data.csv"
raw_file_storage = "./Raw input data files/JRC_Carbon_storage_projects.csv"
raw_file_CO2SToP = "./Raw input data files/CO2StoP/co2jrc_openformats/CO2JRC_OpenFormats/CO2Stop_DataInterrogationSystem/Hydrocarbon_Storage_units.csv"

# Input data files 
scenario_file =     "./Input data files/scenario_data_model_per_ton.xlsx"
shapefile_eu = "./Input data files/Visuals/NUTS_RG_01M_2024_4326.shp/NUTS_RG_01M_2024_4326.shp"
system_data_file_dense = "./Input data files/system_data_dense.xlsx"
system_data_file_coarse = "./Input data files/system_data_coarse.xlsx"
industry_data_file = "./Input data files/industry_system_data.xlsx"
DCCI_file = "./Raw input data files/SP-Global-CI-Cost-Overall-Indexes-Overview-Q2-2024.xlsx"

# Output data files
results_product_file = "./Output data files/Results_product_routes.xlsx"
results_pipes_file = "./Output data files/Results_pipelines.xlsx"
results_stats_file = "./Output data files/Results_statistics.xlsx"
results_industry_file = "./Output data files/Results_industry.xlsx"

results_pipes_file_HPC = "./Output data files/Results_pipelines_HPC.xlsx"
results_stats_file_HPC = "./Output data files/Results_statistics_HPC.xlsx"
results_industry_file_HPC = "./Output data files/Results_industry_HPC.xlsx"

results_pipes_Europe_file_HPC = "./Output data files/Results_pipelines_Europe_HPC.xlsx"
results_stats_Europe_file_HPC = "./Output data files/Results_statistics_Europe_HPC.xlsx"
results_industry_Europe_file_HPC = "./Output data files/Results_industry_Europe_HPC.xlsx"

results_pipes_Trilateral_file_HPC = "./Output data files/Results_pipelines_Trilateral_HPC.xlsx"
results_stats_Trilateral_file_HPC = "./Output data files/Results_statistics_Trilateral_HPC.xlsx"
results_industry_Trilateral_file_HPC = "./Output data files/Results_industry_Trilateral_HPC.xlsx"



# preprosing some files: 
DCCI_values = XLSX.readdata(DCCI_file, "DCCI", "B5:BT7")
DCCI_dict = Dict(DCCI_values[2,i] => DCCI_values[3,i]  for i in 2:length(DCCI_values[1,:]))
XLSX.readdata(DCCI_file, "DCCI", "B5:BT7")
USD_EUR_values = CSV.read(USD_EUR_file, DataFrame)
USD_EUR_values.Year = year.(Date.(USD_EUR_values.Date, "dd/mm/yyyy"))
yearly_avg_price = combine(DataFrames.groupby(USD_EUR_values, :Year), :Price => mean => :Avg_Price)
USD_EUR_dict = Dict(yearly_avg_price[i,"Year"] => yearly_avg_price[i, "Avg_Price"]  for i in 1:length(yearly_avg_price[:,1]))


# functions


function import_data_TandS(file::Any)


    data = XLSX.readxlsx(file)
    Costs = DataFrame(XLSX.readtable(file, "Parameters"))
    Costs[!, :"Value"] = convert.(Float64, Costs[!, :"Value"])
    
    # Shipping = DataFrame(XLSX.readtable(file, "Shipping"))
    Routing_nodes = DataFrame(XLSX.readtable(file, "Routing_nodes")) # filter out all terminal nodes to avoid double nodes with terminals
    Pipelines = DataFrame(XLSX.readtable(file, "Pipelines"))
    Terminals = DataFrame(XLSX.readtable(file, "Terminals"))
    Storage_offshore = DataFrame(XLSX.readtable(file, "Storage_offshore"))
    Storage_inland = DataFrame(XLSX.readtable(file, "Storage_inland"))
    Offshore_nodes = DataFrame(XLSX.readtable(file, "Offshore_nodes"))
    Clusters = DataFrame(XLSX.readtable(file, "Clusters"))

    return Costs, Routing_nodes, Pipelines, Terminals, Storage_offshore, Storage_inland, Offshore_nodes, Clusters
end


function import_data_industry(CO2_tax::Any, Scenario_name::String, Scenario_horizon::Int64)
    # # industry_input_data
    #     data = XLSX.readxlsx(file)
    print("Scenario: $(Scenario_name) $(Scenario_horizon)---------------")
    # Emitters = DataFrame(XLSX.readtable(file, "Industry_$(Scenario_name)_$(Scenario_horizon)"))
    industry_data_file_csv = "./Input data files/CSV inputs/$(CO2_tax)/industry_system_data_$(Scenario_name).csv"
    Emitters = CSV.read(industry_data_file_csv, DataFrame)
    return Emitters
end

function AidRES_scenario_adjustment(raw_file::Any, scenario_file::Any, Project_user_interface_file::Any, Scenario_name::String, Scenario_horizon::Int64, CO2_tax::Int64)
    # Pkg.add(["ExcelFiles", "DataFrames", "DataFramesMeta", "Query", "CSV", "Tables"])

    # raw_file = "./Raw input data files/AidRES_tables_dump.xlsx"
    # system_data_file = "./Input data files/system_data.xlsx"



    energy_commodity_prices = DataFrame(XLSX.readtable(Project_user_interface_file, "energy_commodity_prices"; first_row = 5, header= false, column_labels = ["Commodity", "Preset", "2030", "2050", "Unit"]))
    other_variables = DataFrame(XLSX.readtable(Project_user_interface_file, "other_variables"; first_row = 6, header = false, column_labels = ["Method", "Sector", "Product", "2030", "2050", "Description"]))
    constants = DataFrame(XLSX.readtable(Project_user_interface_file, "constants"; first_row = 5, header= false, column_labels = ["Commodity", "2030", "2050", "Unit"]))
    ammonia_MWhLVH_per_ton =  5.171          # unit converter: https://www.fluxys.com/en/co2/empowering-you/unit-converter
    methanol_MWhLVH_per_ton = 5.543 
   
   


    # Scenario_df = DataFrame(
    #     scenario_id = Scenario_name,
    #     horizon = Scenario_horizon,
    #     electricity_kgco2_kwh = 0.12,
    #     alternative_fuel_mixture_kgco2_kg = 0.0076,
    #     biomass_kgco2_kg = 0.0,
    #     biomass_waste_kgco2_kg = 0.0,
    #     coal_kgco2_kg = 0.49235,
    #     coke_kgco2_kg = 0.3491,
    #     crude_oil_kgco2_kg = 0.23236,
    #     hydrogen_kgco2_kg = 0.0,
    #     methanol_kgco2_kg = 0.66082,
    #     ammonia_kgco2_kg = 2.01,
    #     naphtha_kgco2_kg = 0.23236,
    #     natural_gas_kgco2_kwh = 0.0258,
    #     plastic_mix_kgco2_kg = 1.3892,
    #     electricity_eur_kwh = 0.071,
    #     alternative_fuel_mixture_eur_t = 8.4,
    #     biomass_eur_t = 57,
    #     biomass_waste_eur_t = 57,
    #     coal_eur_t = 125,
    #     coke_eur_t = 52,
    #     crude_oil_eur_t = 370,
    #     hydrogen_eur_kg = 3,
    #     methanol_eur_t = 410,
    #     ammonia_eur_t = 450,
    #     naphtha_eur_t = 390.3,
    #     natural_gas_eur_kwh = 0.025,
    #     plastic_mix_eur_t = 300,
    #     co2_allowance_eur_kgco2 = 0.15
    # ) # scenario 1 corresponing data --> used for check
    Scenario_df = DataFrame(
        scenario_id = Scenario_name,
        horizon = Scenario_horizon,
        electricity_kgco2_kwh = 0.12,
        alternative_fuel_mixture_kgco2_kg = 0.0076,
        biomass_kgco2_kg = 0.0,
        biomass_waste_kgco2_kg = 0.0,
        coal_kgco2_kg = 0.49235,
        coke_kgco2_kg = 0.3491,
        crude_oil_kgco2_kg = 0.23236,
        hydrogen_kgco2_kg = 0.0,
        methanol_kgco2_kg = 0.66082,
        ammonia_kgco2_kg = 2.01,
        naphtha_kgco2_kg = 0.23236,
        natural_gas_kgco2_kwh = 0.0258,
        plastic_mix_kgco2_kg = 1.3892,
        electricity_eur_kwh =               energy_commodity_prices[energy_commodity_prices[:, "Commodity"] .== "Electricity", string(Scenario_horizon)][1], # O.071
        alternative_fuel_mixture_eur_t =    constants[constants[:, "Commodity"] .== "Alternative fuel mix", string(Scenario_horizon)][1], #8.4
        biomass_eur_t =                     100, # constants[constants[:, "Commodity"] .== "Biomass", string(Scenario_horizon)][1], #57 --> 108 = TIMES Be Value 
        biomass_waste_eur_t =               100, # constants[constants[:, "Commodity"] .== "Biomass waste", string(Scenario_horizon)][1], #57 --> 108 =  TIMES Be Value 
        coal_eur_t =                        constants[constants[:, "Commodity"] .== "Coal", string(Scenario_horizon)][1],#125
        coke_eur_t =                        constants[constants[:, "Commodity"] .== "Coke", string(Scenario_horizon)][1],#52
        crude_oil_eur_t =                   constants[constants[:, "Commodity"] .== "Crude oil", string(Scenario_horizon)][1],#370
        hydrogen_eur_kg =                   5.4, #energy_commodity_prices[energy_commodity_prices[:, "Commodity"] .== "Hydrogen", string(Scenario_horizon)][1],#3
        methanol_eur_t =                    constants[constants[:, "Commodity"] .== "Methanol", string(Scenario_horizon)][1], #methanol_MWhLVH_per_ton * energy_commodity_prices[energy_commodity_prices[:, "Commodity"] .== "Methanol", string(Scenario_horizon)],#410 # unit MWHLHV
        ammonia_eur_t =                     constants[constants[:, "Commodity"] .== "Ammonia", string(Scenario_horizon)][1], #ammonia_MWhLVH_per_ton * energy_commodity_prices[energy_commodity_prices[:, "Commodity"] .== "Ammonia", string(Scenario_horizon)],  #450  # unit MWhLHV
        naphtha_eur_t =                     constants[constants[:, "Commodity"] .== "Naphta", string(Scenario_horizon)][1],#390.3
        natural_gas_eur_kwh =               2*energy_commodity_prices[energy_commodity_prices[:, "Commodity"] .== "Natural gas", string(Scenario_horizon)][1],#0.025
        plastic_mix_eur_t =                 constants[constants[:, "Commodity"] .== "Plastic mix", string(Scenario_horizon)][1],#300
        co2_allowance_eur_kgco2 =            CO2_tax/1000 #other_variables[coalesce.(other_variables[:, "Method"], "") .== "Carbon Cost", string(Scenario_horizon)][1]/1000 #0.15
    ) # scenario 1 corresponing data --> used for check
    # Extracting each column's value for the first row:
    
    scenario_id = Scenario_df[1, "scenario_id"]
    horizon = Scenario_df[1, "horizon"]
    electricity_kgco2_kwh = Scenario_df[1, "electricity_kgco2_kwh"]
    alternative_fuel_mixture_kgco2_kg = Scenario_df[1, "alternative_fuel_mixture_kgco2_kg"]
    biomass_kgco2_kg = Scenario_df[1, "biomass_kgco2_kg"]
    biomass_waste_kgco2_kg = Scenario_df[1, "biomass_waste_kgco2_kg"]
    coal_kgco2_kg = Scenario_df[1, "coal_kgco2_kg"]
    coke_kgco2_kg = Scenario_df[1, "coke_kgco2_kg"]
    crude_oil_kgco2_kg = Scenario_df[1, "crude_oil_kgco2_kg"]
    hydrogen_kgco2_kg = Scenario_df[1, "hydrogen_kgco2_kg"]
    methanol_kgco2_kg = Scenario_df[1, "methanol_kgco2_kg"]
    ammonia_kgco2_kg = Scenario_df[1, "ammonia_kgco2_kg"]
    naphtha_kgco2_kg = Scenario_df[1, "naphtha_kgco2_kg"]
    natural_gas_kgco2_kwh = Scenario_df[1, "natural_gas_kgco2_kwh"]
    plastic_mix_kgco2_kg = Scenario_df[1, "plastic_mix_kgco2_kg"]
    electricity_eur_kwh = Scenario_df[1, "electricity_eur_kwh"]
    alternative_fuel_mixture_eur_t = Scenario_df[1, "alternative_fuel_mixture_eur_t"]
    if Scenario_name == "No_Bio"
        biomass_eur_t = Scenario_df[1, "biomass_eur_t"]*10^5 # bio waste still allowed in the no bio scenario. 
        biomass_waste_eur_t = Scenario_df[1, "biomass_waste_eur_t"]*10^5 # Also bio waste not allowed in this scenario 
    else 
        biomass_eur_t = Scenario_df[1, "biomass_eur_t"] # no use of biomass scenarios
        biomass_waste_eur_t = Scenario_df[1, "biomass_waste_eur_t"] # no use of biomass scenario
    end
    coal_eur_t = Scenario_df[1, "coal_eur_t"]
    coke_eur_t = Scenario_df[1, "coke_eur_t"]
    crude_oil_eur_t = Scenario_df[1, "crude_oil_eur_t"]
    hydrogen_eur_kg = Scenario_df[1, "hydrogen_eur_kg"]
    methanol_eur_t = Scenario_df[1, "methanol_eur_t"]
    ammonia_eur_t = Scenario_df[1, "ammonia_eur_t"]
    naphtha_eur_t = Scenario_df[1, "naphtha_eur_t"]
    natural_gas_eur_kwh = Scenario_df[1, "natural_gas_eur_kwh"]
    plastic_mix_eur_t = Scenario_df[1, "plastic_mix_eur_t"]
    co2_allowance_eur_kgco2 = Scenario_df[1, "co2_allowance_eur_kgco2"]
    


    # Original AidRES data files 
    AidRES_model_configuration = DataFrame(XLSX.readtable(raw_file, "AIDRES model_configurations"))
    AidRES_model_perton = DataFrame(XLSX.readtable(raw_file, "AIDRES model_perton"))


    #AidRES_adj_model_perton = DataFrame(XLSX.readtable(AidRES_adj_file, "AIDRES model_perton"))
    AidRES_adj_model_perton = AidRES_model_perton[1:2,:]
    delete!(AidRES_adj_model_perton, [1,2])
    AidRES_adj_model_perton[!, "route_name"] = []  
    AidRES_adj_model_perton[!, "product_id"] = [] 
    AidRES_adj_model_perton[!, "capex_cc_eur_tCO2"] = [] 
    AidRES_adj_model_perton[!, "opex_cc_eur_tCO2"] = [] 
    AidRES_adj_model_perton[!, "totex_cc_eur_tCO2"] = [] 
    AidRES_adj_model_perton[!, "totex_cc_eur_t"] = [] 
    AidRES_adj_model_perton[!, "Additional_cc_capex"] = [] 
    # Extract the allowed configuration for the scenario --> so deleting EU-mix data based on different years 
    EU_mix_allowed_scenario = "EU-mix-$(Scenario_df[1,"horizon"])"
    EU_mix_allowed_2018 = "EU-mix-2018"
    AidRES_old_model_configuration = deepcopy(AidRES_model_configuration) # preserve the old file
    Config_EU_mix_allowed_scenario =  AidRES_old_model_configuration[AidRES_old_model_configuration[:,"route_name"] .== EU_mix_allowed_scenario,:]
    Config_EU_mix_allowed_2018 =  AidRES_old_model_configuration[AidRES_old_model_configuration[:,"route_name"] .== EU_mix_allowed_2018,:]
    Config_EU_mix_allowed = vcat(Config_EU_mix_allowed_scenario, Config_EU_mix_allowed_2018)
    AidRES_new_model_configuration = filter!(row -> !occursin("EU-mix", row.route_name), AidRES_old_model_configuration) 
    AidRES_adj_model_configuration = vcat(AidRES_new_model_configuration, Config_EU_mix_allowed)

    # frac_increase_cc = Scaling_ccts - 1.0  # !!! increase of capture costs with fract_increase_cc if fract_increase_cc is zero: original database
    suffixes = ["Oxy-MEA", "Oxy-CaL", "MEA-DEA", "MEA", "CaL", "DEA", "CC"]

    # see excel called Cost_scaling_cc.xlsx
    Add_capex_cc_cost_df = DataFrame(
        Product_names = ["cement", "chemical-olefins", "chemical-PE", "chemical-PEA", "fertiliser-ammonia","fertiliser-derivates","fertiliser-nitric-acid", "fertiliser-urea", "glass-container", "glass-fibre", "glass-float","refineries-light-liquid-fuel", "steel-primary", "steel-secondary"], 
        Additional_capex_cc_cost = [29.04808326, 18.45710567,2.257336343, 1.127105666, 11.51466888, 0, 11.51466888, 11.51466888, 139, 139, 139, 14.32710567, 0, 0 ]
    )

    # loop over the configuration number 
    
    for (sol_id, config) in enumerate(AidRES_adj_model_configuration[!,"configuration_id"])
        # product specific quantities 
        Config_select = findall(AidRES_model_perton[:, "configuration_id"] .== config)[1] # allows to extract the initial raw input quantities of certain configuration ideas in the model runs of AidRES
        electricity_mwh_t =             AidRES_model_perton[Config_select,"electricity_[mwh/t]"][1]
        biomass_t_t =                   AidRES_model_perton[Config_select,"biomass_[t/t]"][1]
        biomass_waste_t_t =             AidRES_model_perton[Config_select,"biomass_waste_[t/t]"][1]
        coal_t_t =                      AidRES_model_perton[Config_select,"coal_[t/t]"][1]
        coke_t_t =                      AidRES_model_perton[Config_select,"coke_[t/t]"][1]
        crude_oil_t_t =                 AidRES_model_perton[Config_select,"crude_oil_[t/t]"][1]
        hydrogen_t_t =                  AidRES_model_perton[Config_select,"hydrogen_[t/t]"][1]
        methanol_t_t =                  AidRES_model_perton[Config_select,"methanol_[t/t]"][1]
        ammonia_t_t =                   AidRES_model_perton[Config_select,"ammonia_[t/t]"][1]
        naphtha_t_t =                   AidRES_model_perton[Config_select,"naphtha_[t/t]"][1]
        natural_gas_t_t =               AidRES_model_perton[Config_select,"natural_gas_[t/t]"][1]
        natural_gas_kwh_t =              AidRES_model_perton[Config_select,"natural_gas_[gj/t]"][1] * 1/0.0036 # Gj --> kwh 
        plastic_mix_t_t =               AidRES_model_perton[Config_select,"plastic_mix_[t/t]"][1]
        alternative_fuel_mixture_t_t =  AidRES_model_perton[Config_select,"alternative_fuel_mixture_[t/t]"][1]
        direct_emission_tco2_t =        AidRES_model_perton[Config_select,"direct_emission_[tco2/t]"][1]
        # scenario specific calculations 
        opex_var_eur_t =  # eur/ton
            electricity_mwh_t * electricity_eur_kwh *1000 +
            biomass_t_t * biomass_eur_t +
            biomass_waste_t_t * biomass_waste_eur_t +
            coal_t_t * coal_eur_t +
            coke_t_t * coke_eur_t +
            crude_oil_t_t * crude_oil_eur_t +
            hydrogen_t_t * hydrogen_eur_kg *1000 + 
            methanol_t_t * methanol_eur_t +
            ammonia_t_t * ammonia_eur_t +
            naphtha_t_t * naphtha_eur_t +
            natural_gas_kwh_t * natural_gas_eur_kwh +
            plastic_mix_t_t * plastic_mix_eur_t + 
            alternative_fuel_mixture_t_t *alternative_fuel_mixture_eur_t 

        indirect_emissions_tCO2_t =
            electricity_mwh_t * electricity_kgco2_kwh  +
            biomass_t_t * biomass_kgco2_kg  +
            biomass_waste_t_t * biomass_waste_kgco2_kg  +
            coal_t_t * coal_kgco2_kg  +
            coke_t_t * coke_kgco2_kg  +
            crude_oil_t_t * crude_oil_kgco2_kg  +
            hydrogen_t_t * hydrogen_kgco2_kg  + 
            methanol_t_t * methanol_kgco2_kg  +
            ammonia_t_t * ammonia_kgco2_kg  +
            naphtha_t_t * naphtha_kgco2_kg  +
            natural_gas_kwh_t * natural_gas_kgco2_kwh / 1000 +
            plastic_mix_t_t * plastic_mix_kgco2_kg  + 
            alternative_fuel_mixture_t_t *alternative_fuel_mixture_kgco2_kg 

        if Scenario_name == "No_CDR_price" || Scenario_name .== "Exit_no_CDR"
            co2_allowance_eur_t =  # eur/t
                (maximum([0,direct_emission_tco2_t])) * co2_allowance_eur_kgco2 *1000 # you only pay the allowance cost on the direct emissions, not the indirect emissions. If the direct emissions are negative -> you don't want to pay any carbon price/ receive CDR tax. 
        else
            co2_allowance_eur_t =  # eur/t
            (direct_emission_tco2_t) * co2_allowance_eur_kgco2 *1000 # you only pay the allowance cost on the direct emissions, not the indirect emissions
        end
        opex_cst_eur_t =                AidRES_model_perton[Config_select,"opex_cst_[eur/t]"][1] # is NOT the cost of transport and storage 
        capex_eur_t =                   AidRES_model_perton[Config_select,"capex_[eur/t]"][1]

        # extracting capture specific data about additional opex and capex cost compared to the base route. 
        captured_tco2_t = Any[AidRES_model_perton[Config_select,"captured_co2_[tco2/t]"][1]][1]
        name_route = AidRES_adj_model_configuration[AidRES_adj_model_configuration[:, "configuration_id"] .== config, "route_name"][1]
        if captured_tco2_t > 0
            product_id = AidRES_adj_model_configuration[AidRES_adj_model_configuration[:, "configuration_id"] .== config, "product_id"][1]
            name_base_route =  get_no_cc_base_name(name_route, suffixes)
            config_id_base = AidRES_adj_model_configuration[(AidRES_adj_model_configuration[:, "route_name"] .== name_base_route) .& (AidRES_adj_model_configuration[:, "product_id"] .== product_id), "configuration_id"][1] 
            Config_select_base = findall(AidRES_model_perton[:, "configuration_id"] .== config_id_base)[1] 
                electricity_mwh_t_base =             AidRES_model_perton[Config_select_base,"electricity_[mwh/t]"][1]
                biomass_t_t_base =                   AidRES_model_perton[Config_select_base,"biomass_[t/t]"][1]
                biomass_waste_t_t_base =             AidRES_model_perton[Config_select_base,"biomass_waste_[t/t]"][1]
                coal_t_t_base =                      AidRES_model_perton[Config_select_base,"coal_[t/t]"][1]
                coke_t_t_base =                      AidRES_model_perton[Config_select_base,"coke_[t/t]"][1]
                crude_oil_t_t_base =                 AidRES_model_perton[Config_select_base,"crude_oil_[t/t]"][1]
                hydrogen_t_t_base =                  AidRES_model_perton[Config_select_base,"hydrogen_[t/t]"][1]
                methanol_t_t_base =                  AidRES_model_perton[Config_select_base,"methanol_[t/t]"][1]
                ammonia_t_t_base =                   AidRES_model_perton[Config_select_base,"ammonia_[t/t]"][1]
                naphtha_t_t_base =                   AidRES_model_perton[Config_select_base,"naphtha_[t/t]"][1]
                natural_gas_t_t_base =               AidRES_model_perton[Config_select_base,"natural_gas_[t/t]"][1]
                natural_gas_kwh_t_base =             AidRES_model_perton[Config_select_base,"natural_gas_[gj/t]"][1] * 1/0.0036 # Gj --> kwh 
                plastic_mix_t_t_base =               AidRES_model_perton[Config_select_base,"plastic_mix_[t/t]"][1]
                alternative_fuel_mixture_t_t_base =  AidRES_model_perton[Config_select_base,"alternative_fuel_mixture_[t/t]"][1]
                direct_emission_tco2_t_base =        AidRES_model_perton[Config_select_base,"direct_emission_[tco2/t]"][1]
            # scenario specific calculations 
            opex_var_eur_t_base =  # eur/ton
                electricity_mwh_t_base * electricity_eur_kwh *1000 +
                biomass_t_t_base * biomass_eur_t +
                biomass_waste_t_t_base * biomass_waste_eur_t +
                coal_t_t_base * coal_eur_t +
                coke_t_t_base * coke_eur_t +
                crude_oil_t_t_base * crude_oil_eur_t +
                hydrogen_t_t_base * hydrogen_eur_kg *1000 + 
                methanol_t_t_base * methanol_eur_t +
                ammonia_t_t_base * ammonia_eur_t +
                naphtha_t_t_base * naphtha_eur_t +
                natural_gas_kwh_t_base * natural_gas_eur_kwh +
                plastic_mix_t_t_base * plastic_mix_eur_t + 
                alternative_fuel_mixture_t_t_base *alternative_fuel_mixture_eur_t 

            capex_cc =  (AidRES_model_perton[Config_select,"capex_[eur/t]"][1] -     AidRES_model_perton[Config_select_base,"capex_[eur/t]"][1])/ captured_tco2_t
            opex_cc =  (opex_var_eur_t +  opex_cst_eur_t -  AidRES_model_perton[Config_select_base,"opex_cst_[eur/t]"][1]    - opex_var_eur_t_base)/ captured_tco2_t # without allowances 
        else 
            capex_cc = 0.0 
            opex_cc = 0.0 
        end
        additional_cc_capex_cost =  get_additional_capex_cc_costs(AidRES_adj_model_configuration, name_route, suffixes, config, Add_capex_cc_cost_df)

        new_data = DataFrame(
            solution_id =                   Any[sol_id],
            configuration_id =              Any[config],
            scenario_id =                   Any[Scenario_name],
            aidres_sector_id =              Any[AidRES_adj_model_configuration[sol_id,"aidres_sector_id"]],
            horizon =                       Any[Scenario_df[1,"horizon"]],
            electricity_mwh_t =             Any[AidRES_model_perton[Config_select,"electricity_[mwh/t]"][1]],
            electricity_gj_t =              Any[AidRES_model_perton[Config_select,"electricity_[gj/t]"][1]],
            alternative_fuel_mixture_gj_t = Any[AidRES_model_perton[Config_select,"alternative_fuel_mixture_[gj/t]"][1]],
            biomass_gj_t =                  Any[AidRES_model_perton[Config_select,"biomass_[gj/t]"][1]],
            biomass_waste_gj_t =            Any[AidRES_model_perton[Config_select,"biomass_waste_[gj/t]"][1]],
            coal_gj_t =                     Any[AidRES_model_perton[Config_select,"coal_[gj/t]"][1]],
            coke_gj_t =                     Any[AidRES_model_perton[Config_select,"coke_[gj/t]"][1]],
            crude_oil_gj_t =                Any[AidRES_model_perton[Config_select,"crude_oil_[gj/t]"][1]],
            hydrogen_gj_t =                 Any[AidRES_model_perton[Config_select,"hydrogen_[gj/t]"][1]],
            methanol_gj_t =                 Any[AidRES_model_perton[Config_select,"methanol_[gj/t]"][1]],
            ammonia_gj_t =                  Any[AidRES_model_perton[Config_select,"ammonia_[gj/t]"][1]],
            naphtha_gj_t =                  Any[AidRES_model_perton[Config_select,"naphtha_[gj/t]"][1]],
            natural_gas_gj_t =              Any[AidRES_model_perton[Config_select,"natural_gas_[gj/t]"][1]],
            plastic_mix_gj_t =              Any[AidRES_model_perton[Config_select,"plastic_mix_[gj/t]"][1]],
            alternative_fuel_mixture_t_t =  Any[AidRES_model_perton[Config_select,"alternative_fuel_mixture_[t/t]"][1]],
            biomass_t_t =                   Any[AidRES_model_perton[Config_select,"biomass_[t/t]"][1]],
            biomass_waste_t_t =             Any[AidRES_model_perton[Config_select,"biomass_waste_[t/t]"][1]],
            coal_t_t =                      Any[AidRES_model_perton[Config_select,"coal_[t/t]"][1]],
            coke_t_t =                      Any[AidRES_model_perton[Config_select,"coke_[t/t]"][1]],
            crude_oil_t_t =                 Any[AidRES_model_perton[Config_select,"crude_oil_[t/t]"][1]],
            hydrogen_t_t =                  Any[AidRES_model_perton[Config_select,"hydrogen_[t/t]"][1]],
            methanol_t_t =                  Any[AidRES_model_perton[Config_select,"methanol_[t/t]"][1]],
            ammonia_t_t =                   Any[AidRES_model_perton[Config_select,"ammonia_[t/t]"][1]],
            naphtha_t_t =                   Any[AidRES_model_perton[Config_select,"naphtha_[t/t]"][1]],
            natural_gas_t_t =               Any[AidRES_model_perton[Config_select,"natural_gas_[t/t]"][1]],
            plastic_mix_t_t =               Any[AidRES_model_perton[Config_select,"plastic_mix_[t/t]"][1]],
            totex_eur_t =                   Any[opex_var_eur_t + co2_allowance_eur_t + opex_cst_eur_t + capex_eur_t + additional_cc_capex_cost*captured_tco2_t],  # !!! increased with additional_cc_capex_cost eur/tCO2 * tCO2/tproduct
            opex_var_eur_t =                Any[opex_var_eur_t],
            co2_allowance_eur_t =           Any[co2_allowance_eur_t],
            opex_cst_eur_t =                Any[opex_cst_eur_t],
            opex_eur_t =                    Any[opex_var_eur_t + co2_allowance_eur_t + opex_cst_eur_t],  # !!! no increase
            capex_eur_t =                   Any[capex_eur_t + additional_cc_capex_cost*captured_tco2_t],  # !!! increased with additional_cc_capex_cost eur/tCO2 * tCO2/tproduct
            direct_emission_tco2_t =        Any[direct_emission_tco2_t], 
            total_emission_tco2_t =         Any[direct_emission_tco2_t + indirect_emissions_tCO2_t],
            direct_emission_reduction_percent = Any[0],
            total_emission_reduction_percent =  Any[0],
            captured_co2_tco2_t =               Any[AidRES_model_perton[Config_select,"captured_co2_[tco2/t]"][1]], 
            route_name =                        Any[AidRES_adj_model_configuration[AidRES_adj_model_configuration[:, "configuration_id"] .== config, "route_name"][1]],
            product_id =                        Any[AidRES_adj_model_configuration[AidRES_adj_model_configuration[:, "configuration_id"] .== config, "product_id"][1]], 
            capex_cc_eur_tCO2 =                 Any[capex_cc],
            opex_cc_eur_tCO2 =                  Any[opex_cc], 
            totex_cc_eur_tCO2 =                 Any[opex_cc + capex_cc], 
            totex_cc_eur_t =                    Any[(opex_cc + capex_cc)*captured_tco2_t], 
            Additional_cc_capex =               Any[additional_cc_capex_cost]
        )
        rename!(new_data, names(AidRES_adj_model_perton)) # Assigning correct column names to the new_data dataframe. 
        AidRES_adj_model_perton = vcat(AidRES_adj_model_perton,new_data)
 

        # totex_eur_t =                   Any[opex_var_eur_t + co2_allowance_eur_t + opex_cst_eur_t + capex_eur_t + (opex_cc + capex_cc)*captured_tco2_t*frac_increase_cc], 
        # opex_var_eur_t =                Any[opex_var_eur_t],
        # co2_allowance_eur_t =           Any[co2_allowance_eur_t],
        # opex_cst_eur_t =                Any[opex_cst_eur_t],
        # opex_eur_t =                    Any[opex_var_eur_t + co2_allowance_eur_t + opex_cst_eur_t + opex_cc*captured_tco2_t*frac_increase_cc],  # !!! increased with fract_increase_cc if fract_increase_cc is zero: original database
        # capex_eur_t =                   Any[capex_eur_t + capex_cc*captured_tco2_t*frac_increase_cc],  # !!! increased with fract_increase_cc if fract_increase_cc is zero: original database
        # direct_emission_tco2_t =        Any[direct_emission_tco2_t], 


        #new_data_vector = collect(new_data[1,:])

        if Scenario_name .== "Exit" || Scenario_name .== "Exit_no_CDR"
            AidRES_adj_model_perton = AidRES_adj_model_perton[(AidRES_adj_model_perton[:,"aidres_sector_id"] .==2) .|| (AidRES_adj_model_perton[:,"aidres_sector_id"] .==3), :] # only cement (2) & glass (3)
        else 
        end
    end 
    # writing to seperate CSV file 
    file_preprocessing = "./Input data files/CSV inputs/$(CO2_tax)/Scenario_$(Scenario_name)_$(Scenario_horizon)_perton.csv"
    CSV.write(file_preprocessing, AidRES_adj_model_perton)
    # if HPC .== false
    #     XLSX.openxlsx(scenario_file, mode="rw") do xf
    #         SheetName = "$(Scenario_name)_$(Scenario_horizon)_perton"
    #         try 
    #             XLSX.addsheet!(xf, SheetName)
    #         catch 
    #         end
    #         sheet = xf[SheetName]
    #         XLSX.writetable!(sheet,AidRES_adj_model_perton; anchor_cell=XLSX.CellRef("A1")) # NOTE: if shorter df --> some rows of previous run might still be included in excel table. (not yet resolved nicely: https://felipenoris.github.io/XLSX.jl/stable/api/)
    #     end
    # else 
    #     skip 
    # end
    return AidRES_adj_model_perton
end



function write_industrial_emitters_input_data(raw_file::Any, scenario_file::Any, industry_data_file::Any, Scenario_name::String, Scenario_horizon::Int64, CRF::Bool, cluster_save_data::Bool)


    
    AidRES_production_installations = DataFrame(XLSX.readtable(raw_file, "AIDRES production_installations"))
    AidRES_aidres_sector = DataFrame(XLSX.readtable(raw_file, "AIDRES aidres_sectors"))
    AidRES_production_route_types = DataFrame(XLSX.readtable(raw_file, "AIDRES production_route_types"))
    AidRES_product_types = DataFrame(XLSX.readtable(raw_file, "AIDRES product_types"))
    AidRES_industrial_parameters = DataFrame(XLSX.readtable(raw_file, "AIDRES industrial_parameters")) # 2730
    filtered_emitters_not_available = filter!(row -> row.method_type_id .!== 4, deepcopy(AidRES_industrial_parameters)) #1683
    filtered_emitters_steel_rates = filter!(row -> !((row.production_route_id == 1 || row.production_route_id == 2) && (row.parameter_type_id == 1 || row.parameter_type_id == 3)), deepcopy(filtered_emitters_not_available) ) # only contain the steel values where the production rate (kt/yr -nr.2) is entered as parameter_type_id
    filtered_emitters = filtered_emitters_steel_rates
    AidRES_model_configuration = DataFrame(XLSX.readtable(raw_file, "AIDRES model_configurations"))
    # Aidres report: Portland cement II (BV325R with a clinker-to-cement ratio of 70%, is considered as the AIDRES EU reference and LC3 as a future alternative (best case). Portland cement I or cI425R, is a conservative type of cement with a clinker-to-cement ratio of 95% and has one of the highest CO2 emissions (worst case).
    filter!(row -> !occursin("CEM1", row.route_name), AidRES_model_configuration)  # don't allow for CEM1 category (CEM1 Portland cement I - clinker-to-cement ratio of 95%, Portland cement II - clinker-to-cement ratio of 70%), 
    filter!(row -> !occursin("LC3", row.route_name) , AidRES_model_configuration) # don't allow for LC3 cement, because cannot be used for all products (i.e. 10% only)
    AidRES_model_perton = DataFrame(XLSX.readtable(raw_file, "AIDRES model_perton"))
    AidRES_model_results = DataFrame(XLSX.readtable(raw_file, "AIDRES model_results"))

    # Scenario_model_perton =  DataFrame(XLSX.readtable(scenario_file, "$(Scenario_name)_$(Scenario_horizon)_perton"))
    file_preprocessing = "./Input data files/CSV inputs/$(CO2_tax)/Scenario_$(Scenario_name)_$(Scenario_horizon)_perton.csv"
    Scenario_model_perton =  CSV.read(file_preprocessing, DataFrame)


    SECTOR_ID = [AidRES_production_route_types[AidRES_production_route_types[!,"id"] .==i, "aidres_sector_id"][1] for i in filtered_emitters[!,"production_route_id"]] # works
    PRODUCT_ID = [try filtered_emitters[filtered_emitters[!,"id"] .== i, "production_route_id" ][1] catch missing end for i in filtered_emitters[!,"id"]] # works
    PRODUCT_NAMES1 = [try AidRES_production_route_types[AidRES_production_route_types[!, "id"] .== k, "wp1_model_product_name"][1] catch  missing end for k in PRODUCT_ID]
    PRODUCT_NAMES2 = [if value .== "at level of product_type" AidRES_product_types[AidRES_product_types[:,"id"] .== filtered_emitters[nr, "product_type_id"], "wp1_model_produc_name"][1] else value  end for (nr, value) in enumerate(PRODUCT_NAMES1)]
    BASE_EMISSIONS_TOT = [try  AidRES_model_perton[AidRES_model_perton[:, "configuration_id"] .==AidRES_model_configuration[(AidRES_model_configuration[:, "product_id"] .== vl) .& (AidRES_model_configuration[:, "route_name"] .== "EU-mix-2018"), "configuration_id"], "total_emission_[tco2/t]"][1] catch missing end for (nr, vl) in enumerate(PRODUCT_NAMES2)]
    BASE_EMISSIONS_DIRECT = [try  AidRES_model_perton[AidRES_model_perton[:, "configuration_id"] .==AidRES_model_configuration[(AidRES_model_configuration[:, "product_id"] .== vl) .& (AidRES_model_configuration[:, "route_name"] .== "EU-mix-2018"), "configuration_id"], "direct_emission_[tco2/t]"][1] catch missing end for (nr, vl) in enumerate(PRODUCT_NAMES2)]

    if (Scenario_horizon .== 2050) .& (CRF .==true)
        # extracting the reduced production volumes from the different sectors (creates a vector of 1's, 0.69's - fertiliser and 0.29's - refineries)
        Output_fraction = [AidRES_model_results[(AidRES_model_results[:, "aidres_sector_id"] .==i) .& (AidRES_model_results[:, "scenario_id"] .==6), "production_factor"][1] for i in SECTOR_ID]
    elseif (Scenario_horizon .== 2030) .& (CRF .==true)
        Output_fraction = [AidRES_model_results[(AidRES_model_results[:, "aidres_sector_id"] .==i) .& (AidRES_model_results[:, "scenario_id"] .==2), "production_factor"][1] for i in SECTOR_ID]
    else
        Output_fraction = [AidRES_model_results[(AidRES_model_results[:, "aidres_sector_id"] .==i) .& (AidRES_model_results[:, "scenario_id"] .==0), "production_factor"][1] for i in SECTOR_ID]
    end
    SOL1 = zeros(length(filtered_emitters[!,"id"]))
    SOL2 = zeros(length(filtered_emitters[!,"id"]))
    SOLnoCC = zeros(length(filtered_emitters[!,"id"]))
    BIO_CAPTURED_1 =  zeros(length(filtered_emitters[!,"id"]))
    BIO_CAPTURED_2 =  zeros(length(filtered_emitters[!,"id"]))

    for (nr, value) in  enumerate(filtered_emitters[!,"id"])
        # NOTE: we base ourselves on the results per tonne --> if multiplied with Mt --> results in MEur
        POSSIBLE_SOLUTIONS_df = Scenario_model_perton[(Scenario_model_perton[!,"aidres_sector_id"] .== SECTOR_ID[nr]) .&    ([Scenario_model_perton[Scenario_model_perton[!, "solution_id"] .==k,"configuration_id"][1] in(AidRES_model_configuration[AidRES_model_configuration[!,"product_id"] .== PRODUCT_NAMES2[nr], "configuration_id"]) for k in Scenario_model_perton[!,"solution_id"]]),:]
        try 
            totex_vector = POSSIBLE_SOLUTIONS_df[:, "totex_[eur/t]"]
            min_value, min_index = findmin(totex_vector)
            totex_vector[min_index] =  Inf
            Second_min_value, Second_min_index = findmin(totex_vector)
            SOL2[nr] =  POSSIBLE_SOLUTIONS_df[ Second_min_index, "solution_id"]


            if Scenario_name == "CDR_price"
                SOL1[nr] = POSSIBLE_SOLUTIONS_df[argmin(POSSIBLE_SOLUTIONS_df[!, "totex_[eur/t]"]), "solution_id"]
            elseif Scenario_name == "Min_Totex_CCS" 
                filtered_df_CCS =deepcopy(filter(row -> row[Symbol("captured_co2_[tco2/t]")] != 0, POSSIBLE_SOLUTIONS_df))
                if nrow(filtered_df_CCS) > 0
                    # Step 3: If there are rows, select the one with the minimum `totex_[eur/t]`
                    SOL1[nr] = filtered_df_CCS[argmin(filtered_df_CCS[!, "totex_[eur/t]"]), "solution_id"]
                else
                    # Step 4: If no rows have non-zero `captured_co2_[tco2/t]`, select the row with minimum `totex_[eur/t]` from the original DataFrame
                    SOL1[nr] = POSSIBLE_SOLUTIONS_df[argmin(POSSIBLE_SOLUTIONS_df[!, "totex_[eur/t]"]), "solution_id"]
                end
            else
                SOL1[nr] = POSSIBLE_SOLUTIONS_df[argmin(POSSIBLE_SOLUTIONS_df[!, "totex_[eur/t]"]), "solution_id"] 
            end
   
            # if (Scenario_model_perton[Scenario_model_perton[:, "solution_id"] .== SOL1[nr], "captured_co2_[tco2/t]"][1] .- 
            #     0.9*(Scenario_model_perton[Scenario_model_perton[:, "solution_id"] .== SOL1[nr], "direct_emission_[tco2/t]"][1] .+ Scenario_model_perton[Scenario_model_perton[:, "solution_id"] .== SOL1[nr], "captured_co2_[tco2/t]"][1])
            #      > 0.001) # Bio captured amount
            #     BIO_CAPTURED_1_test[nr] = Scenario_model_perton[Scenario_model_perton[:, "solution_id"] .== SOL1[nr], "captured_co2_[tco2/t]"][1] .- 
            #     0.9*(Scenario_model_perton[Scenario_model_perton[:, "solution_id"] .== SOL1[nr], "direct_emission_[tco2/t]"][1] .+ Scenario_model_perton[Scenario_model_perton[:, "solution_id"] .== SOL1[nr], "captured_co2_[tco2/t]"][1])
                
            # else
            # end 
            ROUTE_NM_1 = AidRES_model_configuration[AidRES_model_configuration[!, "configuration_id"] .== Scenario_model_perton[Scenario_model_perton[!, "solution_id"] .== SOL1[nr], "configuration_id"], "route_name"][1] 
            ROUTE_NM_2 = AidRES_model_configuration[AidRES_model_configuration[!, "configuration_id"] .== Scenario_model_perton[Scenario_model_perton[!, "solution_id"] .== SOL2[nr], "configuration_id"], "route_name"][1] 
            
            if any(occursin.(["BM", "BMW"], ROUTE_NM_1))
                # E_FOSSIL = Scenario_model_perton[Scenario_model_perton[:, "solution_id"] .== SOL1[nr], "direct_emission_[tco2/t]"][1] + Scenario_model_perton[Scenario_model_perton[:, "solution_id"] .== SOL1[nr], "captured_co2_[tco2/t]"][1]
                # E_BIO = Scenario_model_perton[Scenario_model_perton[:, "solution_id"] .== SOL1[nr], "captured_co2_[tco2/t]"][1]/0.9 - E_FOSSIL
                BIO_CAPTURED_1[nr] = Scenario_model_perton[Scenario_model_perton[:, "solution_id"] .== SOL1[nr], "captured_co2_[tco2/t]"][1] 
                #     BIO_CAPTURED_1[nr] = Scenario_model_perton[Scenario_model_perton[:, "solution_id"] .== SOL1[nr], "captured_co2_[tco2/t]"][1] .- 
                #     0.9*(Scenario_model_perton[Scenario_model_perton[:, "solution_id"] .== SOL1[nr], "direct_emission_[tco2/t]"][1] .+ Scenario_model_perton[Scenario_model_perton[:, "solution_id"] .== SOL1[nr], "captured_co2_[tco2/t]"][1])
                #     FOSSIL_CAPTURE_1[nr] = 0.9*(Scenario_model_perton[Scenario_model_perton[:, "solution_id"] .== SOL1[nr], "captured_co2_[tco2/t]"][1] + Scenario_model_perton[Scenario_model_perton[:, "solution_id"] .== SOL1[nr], "direct_emission_[tco2/t]"][1])
                #     TOTAL_CAPTURE_1[nr]  = Scenario_model_perton[Scenario_model_perton[:, "solution_id"] .== SOL1[nr], "captured_co2_[tco2/t]"][1]
                #     BIO_CAPTURED_1[nr]  = TOTAL_CAPTURE_1[nr] - FOSSIL_CAPTURE_1[nr]
                # 
            else
            end

            if any(occursin.(["BM", "BMW"], ROUTE_NM_2))
                BIO_CAPTURED_2[nr] = Scenario_model_perton[Scenario_model_perton[:, "solution_id"] .== SOL2[nr], "captured_co2_[tco2/t]"][1] 

            else
            end


            # if (Scenario_model_perton[Scenario_model_perton[:, "solution_id"] .== SOL1[nr], "direct_emission_[tco2/t]"][1] < 0.0)
            #     BIO_CAPTURED_1[nr] = Scenario_model_perton[Scenario_model_perton[:, "solution_id"] .== SOL1[nr], "captured_co2_[tco2/t]"][1] 

            # else
            # end

            # if (Scenario_model_perton[Scenario_model_perton[:, "solution_id"] .== SOL2[nr], "direct_emission_[tco2/t]"][1] < 0.0)
            #     BIO_CAPTURED_2[nr] = Scenario_model_perton[Scenario_model_perton[:, "solution_id"] .== SOL2[nr], "captured_co2_[tco2/t]"][1] 
            # else
            # end

        catch 
            SOL1[nr] = NaN
            SOL2[nr] = NaN 
        end

        try 
            NOCC_SOLUTIONS = POSSIBLE_SOLUTIONS_df[POSSIBLE_SOLUTIONS_df[:, "captured_co2_[tco2/t]"] .== 0,:]
            min_value_nocc , min_index_nocc =    findmin(NOCC_SOLUTIONS[:, "totex_[eur/t]"])
            SOLnoCC[nr] =  NOCC_SOLUTIONS[ min_index_nocc, "solution_id"]

        catch 
            SOLnoCC[nr] = NaN
        end


    end

    # BIO_CAPTURED_1 = ifelse.(BIO_CAPTURED_1 .< 0.001, 0, BIO_CAPTURED_1)
    # BIO_CAPTURED_2 = ifelse.(BIO_CAPTURED_2 .< 0.001, 0, BIO_CAPTURED_2)

    # [AidRES_model_perton[AidRES_model_perton[!, "solution_id"] .==k,"configuration_id"][1] in(AidRES_model_configuration[AidRES_model_configuration[!,"product_id"] .== PRODUCT_NAMES2[nr], "configuration_id"]) for k in AidRES_model_perton[!,"solution_id"]]

   IndEmitters_df_raw = DataFrame(
        Emitter_id = ["E$(value)" for value in filtered_emitters[:,"id"]],
        Node_id = ["C$(filtered_emitters[i,"aidres_site_id"])" for i in 1:length(filtered_emitters[:,"aidres_site_id"])], # still to adjust
        AidRES_site_id = filtered_emitters[!,"aidres_site_id"],
        NUTS0 = [try  AidRES_production_installations[AidRES_production_installations[!,"aidres_site_id"] .== i,"registry_code"][1]  catch missing end for i in filtered_emitters[!,"aidres_site_id"]],
        NUTS3 =[try  AidRES_production_installations[AidRES_production_installations[!,"aidres_site_id"] .== i,"nuts3_code"][1]  catch missing end for i in filtered_emitters[!,"aidres_site_id"]],
        Lat =[try  AidRES_production_installations[AidRES_production_installations[!,"aidres_site_id"] .== i,"geolocation_lat"][1]  catch missing end for i in filtered_emitters[!,"aidres_site_id"]],
        Lon =[try  AidRES_production_installations[AidRES_production_installations[!,"aidres_site_id"] .== i,"geolocation_long"][1]  catch missing end for i in filtered_emitters[!,"aidres_site_id"]],
        Sector_id = SECTOR_ID,
        Sector_name = [try AidRES_aidres_sector[AidRES_aidres_sector[!,"id"] .== i, "name" ][1] catch missing end for i in SECTOR_ID],
        Product_route_id = PRODUCT_ID, # order is NOT according to the id in the AIDRES industrial_parameters tap, but according to the excel index
        Product_route_name = PRODUCT_NAMES2,
        Product_cap_ktpa = Output_fraction.*filtered_emitters[!,"value"], # capacity is reduced by expected production output in 2018/2030/2050 
        Config_id_1 = [try Scenario_model_perton[Scenario_model_perton[!, "solution_id"] .== i, "configuration_id"][1] catch missing end for i in SOL1], 
        Config_id_2 = [try Scenario_model_perton[Scenario_model_perton[!, "solution_id"] .== i, "configuration_id"][1] catch missing end for i in SOL2],
        Config_id_noCC = [try Scenario_model_perton[Scenario_model_perton[!, "solution_id"] .== i, "configuration_id"][1] catch missing end for i in SOLnoCC],
        Route_name_1 = [try AidRES_model_configuration[AidRES_model_configuration[!, "configuration_id"] .== Scenario_model_perton[Scenario_model_perton[!, "solution_id"] .== i, "configuration_id"], "route_name"][1] catch missing end for i in SOL1],
        Route_name_2 = [try AidRES_model_configuration[AidRES_model_configuration[!, "configuration_id"] .== Scenario_model_perton[Scenario_model_perton[!, "solution_id"] .== i, "configuration_id"], "route_name"][1] catch missing end for i in SOL2],
        Route_name_noCC = [try AidRES_model_configuration[AidRES_model_configuration[!, "configuration_id"] .== Scenario_model_perton[Scenario_model_perton[!, "solution_id"] .== i, "configuration_id"], "route_name"][1] catch missing end for i in SOLnoCC],
        Base_emissions_tot_tCO2ptpa= BASE_EMISSIONS_TOT, #EU mix 2018 (= all fossil emissions)
        Base_emissions_direct_tCO2ptpa= BASE_EMISSIONS_DIRECT, #EU mix 2018 (= all fossil emissions)
        Captured_CO2_1_tCO2ptpa = [try Scenario_model_perton[Scenario_model_perton[!, "solution_id"] .== i, "captured_co2_[tco2/t]"][1] catch missing 0 end for i in SOL1],
        Captured_CO2_2_tCO2ptpa = [try Scenario_model_perton[Scenario_model_perton[!, "solution_id"] .== i, "captured_co2_[tco2/t]"][1] catch missing 0 end for i in SOL2],
        Capture_ofwhich_bio_1_tCO2ptpa = BIO_CAPTURED_1,
        Capture_ofwhich_bio_2_tCO2ptpa = BIO_CAPTURED_2,
        Totex_1_EURptpa = [try Scenario_model_perton[Scenario_model_perton[!, "solution_id"] .== i, "totex_[eur/t]"][1] catch missing 0 end for i in SOL1], # NOTE: TOTEX does not contain T&S costs of capture value chain!!
        Totex_2_EURptpa = [try Scenario_model_perton[Scenario_model_perton[!, "solution_id"] .== i, "totex_[eur/t]"][1] catch missing  0 end for i in SOL2],
        Totex_noCC_EURptpa = [try Scenario_model_perton[Scenario_model_perton[!, "solution_id"] .== i, "totex_[eur/t]"][1] catch missing 0 end for i in SOLnoCC],
        Capex_1_EURptpa = [try Scenario_model_perton[Scenario_model_perton[!, "solution_id"] .== i, "capex_[eur/t]"][1] catch missing  0 end for i in SOL1],
        Capex_2_EURptpa = [try Scenario_model_perton[Scenario_model_perton[!, "solution_id"] .== i, "capex_[eur/t]"][1] catch missing  0 end for i in SOL2],
        Capex_noCC_EURptpa = [try Scenario_model_perton[Scenario_model_perton[!, "solution_id"] .== i, "capex_[eur/t]"][1] catch missing 0 end for i in SOLnoCC],
        Opex_noTandS_1_EURptpa = [try Scenario_model_perton[Scenario_model_perton[!, "solution_id"] .== i, "opex_[eur/t]"][1] catch missing 0  end for i in SOL1],
        Opex_noTandS_2_EURptpa = [try Scenario_model_perton[Scenario_model_perton[!, "solution_id"] .== i, "opex_[eur/t]"][1] catch missing 0 end for i in SOL2], 
        Opex_noTandS_noCC_EURptpa = [try Scenario_model_perton[Scenario_model_perton[!, "solution_id"] .== i, "opex_[eur/t]"][1] catch missing 0 end for i in SOLnoCC], 
        CO2_allowance_cost_1_EURpt = [try Scenario_model_perton[Scenario_model_perton[!, "solution_id"] .== i, "co2_allowance_[eur/t]"][1] catch missing 0 end for i in SOL1],
        direct_emission_1_tco2_t = [try Scenario_model_perton[Scenario_model_perton[!, "solution_id"] .== i, "direct_emission_[tco2/t]"][1] catch missing 0 end for i in SOL1],
        direct_emission_2_tco2_t = [try Scenario_model_perton[Scenario_model_perton[!, "solution_id"] .== i, "direct_emission_[tco2/t]"][1] catch missing 0 end for i in SOL2],
        direct_emission_noCC_tco2_t = [try Scenario_model_perton[Scenario_model_perton[!, "solution_id"] .== i, "direct_emission_[tco2/t]"][1] catch missing 0 end for i in SOLnoCC],
        total_emission_1_tco2_t = [try Scenario_model_perton[Scenario_model_perton[!, "solution_id"] .== i, "total_emission_[tco2/t]"][1] catch missing 0 end for i in SOL1],
        total_emission_2_tco2_t = [try Scenario_model_perton[Scenario_model_perton[!, "solution_id"] .== i, "total_emission_[tco2/t]"][1] catch missing 0 end for i in SOL2],
        total_emission_noCC_tco2_t = [try Scenario_model_perton[Scenario_model_perton[!, "solution_id"] .== i, "total_emission_[tco2/t]"][1] catch missing 0 end for i in SOLnoCC]
        )


    IndEmitters_df = IndEmitters_df_raw
        
    # deleting rows 
    deleteat!(IndEmitters_df, findall(IndEmitters_df.Product_route_name .== "not included in blue-print model"))
    deleteat!(IndEmitters_df, findall(IndEmitters_df.Product_route_name .== "fertiliser-derivates"))
    deleteat!(IndEmitters_df, findall(IndEmitters_df.Lat .== 0))
    dropmissing!(IndEmitters_df, :Product_cap_ktpa)
    deleteat!(IndEmitters_df, findall(IndEmitters_df.Product_cap_ktpa .== Float64.(0.0))) # 1233

    Centroids_df, IndEmitters_df = clustering_DBSCAN(IndEmitters_df, max_distance) 
    global Centroids_df
    if cluster_save_data .== true 
        XLSX.openxlsx(system_data_file, mode="rw") do xf

            SheetName = "Clusters"
            try 
                XLSX.addsheet!(xf, SheetName)
            catch 
            end
            sheet = xf[SheetName]
            XLSX.writetable!(sheet,Centroids_df; anchor_cell=XLSX.CellRef("A1")) # NOTE: if shorter df --> some rows of previous run might still be included in excel table. (not yet resolved nicely: https://felipenoris.github.io/XLSX.jl/stable/api/)
        end
    else 
        skip 
    end 
    industry_data_file_csv = "./Input data files/CSV inputs/$(CO2_tax)/industry_system_data_$(Scenario_name).csv"
    something.(IndEmitters_df, missing)    |> CSV.write(industry_data_file_csv)

    # XLSX.openxlsx(industry_data_file, mode="rw") do xf
    #     SheetName = "Industry_$(Scenario_name)_$(Scenario_horizon)"
    #     try 
    #         XLSX.addsheet!(xf, SheetName)
    #     catch 
    #     end
    #     sheet = xf[SheetName]
    #     XLSX.writetable!(sheet,IndEmitters_df; anchor_cell=XLSX.CellRef("A1")) # NOTE: if shorter df --> some rows of previous run might still be included in excel table. (not yet resolved nicely: https://felipenoris.github.io/XLSX.jl/stable/api/)
    # end


    return IndEmitters_df
end

function make_unique_ids!(Routing_nodes_raw_df, Node_id, Node_name, Lat, Lon)
    # Group by the node_id
    Routing_nodes_raw_df.INDEX = 1:nrow(Routing_nodes_raw_df)
    grouped = DataFrames.groupby(Routing_nodes_raw_df, :Node_id)
    
    # Iterate through each group
    for g in grouped
        # If there are duplicates based on lat/lon
        if nrow(g) > 1
            for i in 1:nrow(g)
                # Modify node_id and node_name to make them unique
                suffix = "_$i"  # Add a unique suffix for each duplicate
                Routing_nodes_raw_df[g[i, :].INDEX, "Node_id"] *= suffix  # Update node_id
                Routing_nodes_raw_df[g[i, :].INDEX, "Node_name"] *= suffix  # Update node_name
            end
        end
    end
end


function writing_terminal_input_data(raw_file_oil_terminals, raw_file_gas_terminals, EU_shape_file, system_data_file)
    

    D = gmtread(EU_shape_file)

    Raw_terminals_oil = CSV.read(raw_file_oil_terminals, DataFrame)
    Raw_terminals_gas = CSV.read(raw_file_gas_terminals, DataFrame)



    Terminal_nodes_raw_df = DataFrame(
        Node_id = ["T$(i)" for i in 1:(length(Raw_terminals_oil[:,"terminal"]) + length( Raw_terminals_gas[:,"id"]))],
        Node_name = vcat(Raw_terminals_oil[:,"terminal"], Raw_terminals_gas[:,"name"]),
        Lat =  vcat(Raw_terminals_oil[:,"eigl_text_lat"],  Raw_terminals_gas[:,"lat"]),
        Lon = vcat(Raw_terminals_oil[:,"eigl_text_lon"], Raw_terminals_gas[:,"long"])
        )
    
    Terminal_harbour_nodes_df = Terminal_nodes_raw_df
    # Defining all harbour located entries
   
    # margin_km = 75
    # Inland_entries = [point_inland_outside_margin(Terminal_nodes_raw_df[i,"Lon"], Terminal_nodes_raw_df[i,"Lat"], D, margin_km) for i in 1:length(Terminal_nodes_raw_df[:,"Lon"])]
    # Harbour_entries = .!Inland_entries
    

    # Terminal_harbour_nodes_df = Terminal_nodes_raw_df[Harbour_entries, :]
    
    
    XLSX.openxlsx(system_data_file, mode="rw") do xf
        SheetName = "Terminals"
        try 
            XLSX.addsheet!(xf, SheetName)
        catch 
        end
        sheet = xf[SheetName]
        XLSX.writetable!(sheet,Terminal_harbour_nodes_df; anchor_cell=XLSX.CellRef("A1")) # NOTE: if shorter df --> some rows of previous run might still be included in excel table. (not yet resolved nicely: https://felipenoris.github.io/XLSX.jl/stable/api/)
    end

    return Terminal_harbour_nodes_df 
end



function writing_routing_input_data(raw_file_gas, system_data_file)

  
    # raw_file_gas = "./Raw input data files/IGGIELGN/data/IGGIELGN_PipeSegments.csv"
    Raw_PipeSegments_gas_1 =  CSV.read(raw_file_gas, DataFrame)
    grouped = DataFrames.groupby(Raw_PipeSegments_gas_1, :node_id)
    counts_df = combine(grouped, nrow => :count)
    unique_node_ids = counts_df[counts_df.count .== 1, :node_id]
    Raw_PipeSegments_gas = filter(row -> row.node_id in unique_node_ids, Raw_PipeSegments_gas_1)



    NODE_ORIGIN =  Vector{String}(undef, length(Raw_PipeSegments_gas[:,"node_id"]))
    NODE_DESTINATION =  Vector{String}(undef, length(Raw_PipeSegments_gas[:,"node_id"]))

    for (index, s) in enumerate(Raw_PipeSegments_gas[:,"node_id"])
        o = match(r"'([^']*)'", s)
        NODE_ORIGIN[index] = o.captures[1]
        comma_index = findfirst(',', s)
        second_part = s[comma_index+1:end]
        first_quote_index = findfirst("'", second_part)[1]
        last_quote_index = findlast("'", second_part)[1]
        d = second_part[first_quote_index+1:last_quote_index-1]
        NODE_DESTINATION[index] = d
    end
    
    LAT_START =  Vector{Float64}(undef, length(Raw_PipeSegments_gas[:,"node_id"]))
    LAT_END = Vector{Float64}(undef, length(Raw_PipeSegments_gas[:,"node_id"]))
    LON_START =  Vector{Float64}(undef, length(Raw_PipeSegments_gas[:,"node_id"]))
    LON_END = Vector{Float64}(undef, length(Raw_PipeSegments_gas[:,"node_id"]))

    for (index, s) in enumerate(Raw_PipeSegments_gas[:,"lat"])
  
        # Remove the brackets by replacing them with an empty string
        s_clean = replace(s, '[' => "", ']' => "")
        
        # Split the string into parts using the comma as a delimiter
        parts = split(s_clean, ", ")
        
        # Convert the parts to Float64 and create a vector
        vector_lat = [parse(Float64, part) for part in parts]
        
        LAT_START[index] = vector_lat[1]
        LAT_END[index] = vector_lat[2]
    end

    for (index, s) in enumerate(Raw_PipeSegments_gas[:,"long"])
  
        # Remove the brackets by replacing them with an empty string
        s_clean = replace(s, '[' => "", ']' => "")
        
        # Split the string into parts using the comma as a delimiter
        parts = split(s_clean, ", ")
        
        # Convert the parts to Float64 and create a vector
        vector_lon = [parse(Float64, part) for part in parts]
        
        LON_START[index] = vector_lon[1]
        LON_END[index] = vector_lon[2]
    end


    Routing_nodes_raw_df = DataFrame(
        Node_id = vcat(NODE_ORIGIN,NODE_DESTINATION),
        Node_name = vcat(NODE_ORIGIN,NODE_DESTINATION),
        Lat =  vcat(LAT_START,LAT_END),
        Lon = vcat(LON_START,LON_END)
        )

        
    Routing_nodes_df = unique(Routing_nodes_raw_df)


    # # ensuring that same nodes are not covered by terminal nodes 
    # for (i, (r_lat, r_lon)) in enumerate(zip(Routing_nodes_df[:,"Lat"], Routing_nodes_df[:,"Lon"]))
    #     R_lat = round(r_lat, digits = 4)
    #     R_lon = round(r_lon, digits = 4)
    #     for k in 1:length(Terminal_harbour_nodes_df[:, "Lon"])
    #         if (R_lat, R_lon)== (round(Terminal_harbour_nodes_df[k, "Lat"], digits = 4), round(Terminal_harbour_nodes_df[k, "Lon"], digits=4))
    #             Routing_nodes_df[i,"Node_id"] = Terminal_harbour_nodes_df[k, "Node_id"]
    #         end
    #     end
    # end
   
    
    ######################################################################################
    if detail_level == "coarse"   
        # Make sure that all nodes have unique names (at least if their lat and long are not the same)
        Routing_nodes_df.INDEX = 1:nrow(Routing_nodes_df)
        grouped = DataFrames.groupby(Routing_nodes_df, :Node_id)
        
        # Iterate through each group
        duplicates = 0
        for g in grouped
            # If there are duplicates based on lat/lon
            if nrow(g) > 1
                duplicates += 1
                for i in 1:nrow(g)
                    # Modify node_id and node_name to make them unique
                    suffix = "_$i"  # Add a unique suffix for each duplicate
                    Routing_nodes_df[g[i, :].INDEX, "Node_id"] *= suffix  # Update node_id
                    Routing_nodes_df[g[i, :].INDEX, "Node_name"] *= suffix  # Update node_name
                end
            end
        end
       print(duplicates)
    else 
    end
    ######################################################################################



    latitudes = Routing_nodes_df[:, "Lat"]
    longitudes = Routing_nodes_df[:, "Lon"]

    # Create a 2xN matrix
    gc = Geocoder()   
    Country_code_r = [decode(gc, SA[latitudes[i], longitudes[i]])[2] for i in 1:length(latitudes)]
    Routing_nodes_df[:, "NUTS0"] = Country_code_r


    XLSX.openxlsx(system_data_file, mode="rw") do xf
        SheetName = "Routing_nodes"
        try 
            XLSX.addsheet!(xf, SheetName)
        catch 
        end
        sheet = xf[SheetName]
        XLSX.writetable!(sheet,Routing_nodes_df; anchor_cell=XLSX.CellRef("A1")) # NOTE: if shorter df --> some rows of previous run might still be included in excel table. (not yet resolved nicely: https://felipenoris.github.io/XLSX.jl/stable/api/)
    end

    return Routing_nodes_df
end




function writing_offshore_nodes_input_data(raw_file_offshore_nodes, system_data_file)
    
    
    Raw_offshore_coordinates = CSV.read(raw_file_offshore_nodes, DataFrame)




    Offshore_nodes_raw_df = DataFrame(
        Node_id = Raw_offshore_coordinates[!,"Id"],
        Node_name = Raw_offshore_coordinates[!,"Name"],
        Lat =  Raw_offshore_coordinates[!,"Lat"],
        Lon =  Raw_offshore_coordinates[!,"Lon"]
    )
    



    Offshore_nodes_df = Offshore_nodes_raw_df
    
    
    XLSX.openxlsx(system_data_file, mode="rw") do xf
        SheetName = "Offshore_nodes"
        try 
            XLSX.addsheet!(xf, SheetName)
        catch 
        end
        sheet = xf[SheetName]
        XLSX.writetable!(sheet,Offshore_nodes_df; anchor_cell=XLSX.CellRef("A1")) # NOTE: if shorter df --> some rows of previous run might still be included in excel table. (not yet resolved nicely: https://felipenoris.github.io/XLSX.jl/stable/api/)
    end

    return Offshore_nodes_df
end


function writing_CO2SToP_input_data(raw_file_CO2SToP, system_data_file)

    CO2SToP_carbon_storage_projects_raw =  CSV.read(raw_file_CO2SToP, DataFrame)
    CO2SToP_carbon_storage_projects_raw = filter(row -> row."EST_STORECAP_MEAN" != 0,     CO2SToP_carbon_storage_projects_raw)
    CO2SToP_carbon_storage_projects_raw = filter(row -> !ismissing(row."Projection_Info"),     CO2SToP_carbon_storage_projects_raw)

   
    # Coordinate systems checked with ChatGPT and https://epsg.io/transform#s_srs=25830&t_srs=4326&x=714606.1211000&y=4613026.0799000
    # trans = Proj4.Transformation("EPSG:25830", "EPSG:4326")    # Correct transformation: from EPSG:25832 to WGS84 (EPSG:4326)
    # latlon = [trans([x, y])    for (x, y) in zip(CO2SToP_carbon_storage_projects[:, "X"], CO2SToP_carbon_storage_projects[:, "Y"])]
    # CO2SToP_carbon_storage_projects.Lat = [latlon[i][1] for i in 1:length(latlon)]
    # CO2SToP_carbon_storage_projects.Lon = [latlon[i][2] for i in 1:length(latlon)]
    CO2SToP_carbon_storage_projects =   country_coordinate_transform(CO2SToP_carbon_storage_projects_raw)
   
    Onshore_entries = [inecos(D, CO2SToP_carbon_storage_projects[i,"Lon"], CO2SToP_carbon_storage_projects[i,"Lat"]) for i in 1:length(CO2SToP_carbon_storage_projects[:,"Lon"])] #when point falls inside polygon
    Offshore_entries =  .!Onshore_entries

    Offshore_storages_df_raw = DataFrame(
        Node_id =  ["So$(i)" for i in 1:sum(Offshore_entries)], 
        Storage_name = CO2SToP_carbon_storage_projects[Offshore_entries, "STORAGE_UNIT_NAME"],
        X = CO2SToP_carbon_storage_projects[Offshore_entries, "X"],
        Y = CO2SToP_carbon_storage_projects[Offshore_entries, "Y"], 
        Lat = CO2SToP_carbon_storage_projects[Offshore_entries, "Lat"],
        Lon = CO2SToP_carbon_storage_projects[Offshore_entries, "Lon"],
        # Planned_inj_mtpa = JRC_carbon_storage_projects[Offshore_entries, "planned_injection_mt"], #
        Theoretical_volume_mt = CO2SToP_carbon_storage_projects[Offshore_entries, "EST_STORECAP_MEAN"],   # 
        # Fake_storage_capacity_mtpa = [200 for i in  1:sum(Offshore_entries)],
        Cap_estimation_method = CO2SToP_carbon_storage_projects[Offshore_entries, "CAP_EST_METHOD"], 
        Country =  CO2SToP_carbon_storage_projects[Offshore_entries, "COUNTRY"]
    )

    # Extract latitude and longitude
    latitudes = Offshore_storages_df_raw[:, "Lat"]
    longitudes = Offshore_storages_df_raw[:, "Lon"]

    # Create a 2xN matrix
    coordinate_matrix = hcat(latitudes, longitudes)
    gc = Geocoder()   
    Country_code_off = [decode(gc, SA[latitudes[i], longitudes[i]])[2] for i in 1:length(latitudes)]
    Offshore_storages_df_raw[:, "NUTS0"] = Country_code_off

    Inland_storages_df_raw = DataFrame(
        Node_id =  ["Si$(i)" for i in 1:sum(Onshore_entries)], 
        Storage_name = CO2SToP_carbon_storage_projects[Onshore_entries, "STORAGE_UNIT_NAME"], 
        Lat = CO2SToP_carbon_storage_projects[Onshore_entries, "Lat"],
        Lon = CO2SToP_carbon_storage_projects[Onshore_entries, "Lon"],
        # Planned_inj_mtpa = JRC_carbon_storage_projects[Offshore_entries, "planned_injection_mt"], #
        Theoretical_volume_mt = CO2SToP_carbon_storage_projects[Onshore_entries, "EST_STORECAP_MEAN"],   # 
        # Fake_storage_capacity_mtpa = [200 for i in  1:sum(Offshore_entries)],
        Cap_estimation_method = CO2SToP_carbon_storage_projects[Onshore_entries, "CAP_EST_METHOD"], 
        Country =  CO2SToP_carbon_storage_projects[Onshore_entries, "COUNTRY"]
    )
    # Extract latitude and longitude
    latitudes = Inland_storages_df_raw[:, "Lat"]
    longitudes = Inland_storages_df_raw[:, "Lon"]

    # Create a 2xN matrix
    coordinate_matrix = hcat(latitudes, longitudes)
    gc = Geocoder()   
    Country_code_inl = [decode(gc, SA[latitudes[i], longitudes[i]])[2] for i in 1:length(latitudes)]
    Inland_storages_df_raw[:, "NUTS0"] = Country_code_inl
    
    
    Offshore_storages_df = Offshore_storages_df_raw
    Inland_storages_df = Inland_storages_df_raw

end 

return 


function writing_storages_input_data(raw_file_storage, system_data_file)

    EU_shape_file = "./Raw input data files/Europe/Europe_merged.shp"
    D = gmtread(EU_shape_file);


    JRC_carbon_storage_projects =  CSV.read(raw_file_storage, DataFrame);

     Onshore_entries = [inecos(D, JRC_carbon_storage_projects[i,"eigl_text_lon"], JRC_carbon_storage_projects[i,"eigl_text_lat"]) for i in 1:length(JRC_carbon_storage_projects[:,"eigl_text_lon"])] #when point falls inside polygon
     Offshore_entries =  .!Onshore_entries
        # Apply the transformation to the DataFrame
    Theoretical_volumes = [transform_value_storage_cap(val) for val in JRC_carbon_storage_projects[:, "storage_volume_mt"]] # FV: should be divided by 100 maybe 

   
    Offshore_storages_df_raw = DataFrame(
        Node_id =  ["So$(i)" for i in 1:sum(Offshore_entries)], 
        Storage_name = JRC_carbon_storage_projects[Offshore_entries, "storage_location"], 
        Lat = JRC_carbon_storage_projects[Offshore_entries, "eigl_text_lat"],
        Lon = JRC_carbon_storage_projects[Offshore_entries, "eigl_text_lon"],
        Planned_inj_mt = JRC_carbon_storage_projects[Offshore_entries, "planned_injection_mt"], #
        Theoretical_volume_mt =  Theoretical_volumes[Offshore_entries], # 
        Srl = JRC_carbon_storage_projects[Offshore_entries, "srl"], # storage readiness level 
        Project_status = JRC_carbon_storage_projects[Offshore_entries, "project_status"]
    )
    # Extract latitude and longitude
    latitudes = Offshore_storages_df_raw[:, "Lat"]
    longitudes = Offshore_storages_df_raw[:, "Lon"]

    # Create a 2xN matrix
    coordinate_matrix = hcat(latitudes, longitudes)
    gc = Geocoder()   
    Country_code_off = [decode(gc, SA[latitudes[i], longitudes[i]])[2] for i in 1:length(latitudes)]
    Offshore_storages_df_raw[:, "NUTS0"] = Country_code_off
    
        
    Inland_storages_df_raw = DataFrame(
        Node_id =  ["Si$(i)" for i in 1:sum(Onshore_entries)], 
        Storage_name = JRC_carbon_storage_projects[Onshore_entries, "storage_location"], 
        Lat = JRC_carbon_storage_projects[Onshore_entries, "eigl_text_lat"],
        Lon = JRC_carbon_storage_projects[Onshore_entries, "eigl_text_lon"],
        Planned_inj_mt = JRC_carbon_storage_projects[Onshore_entries, "planned_injection_mt"], # still to clean up 
        Theoretical_volume_mt =  Theoretical_volumes[Onshore_entries], # still to clean up 
        Srl = JRC_carbon_storage_projects[Onshore_entries, "srl"], # storage readiness level 
        Project_status = JRC_carbon_storage_projects[Onshore_entries, "project_status"]
    )
    # Extract latitude and longitude
    latitudes = Inland_storages_df_raw[:, "Lat"]
    longitudes = Inland_storages_df_raw[:, "Lon"]

    # Create a 2xN matrix
    coordinate_matrix = hcat(latitudes, longitudes)
    gc = Geocoder()   
    Country_code_inl = [decode(gc, SA[latitudes[i], longitudes[i]])[2] for i in 1:length(latitudes)]
    Inland_storages_df_raw[:, "NUTS0"] = Country_code_inl
    
    
    Offshore_storages_df = Offshore_storages_df_raw
    Inland_storages_df = Inland_storages_df_raw

    XLSX.openxlsx(system_data_file, mode="rw") do xf
        SheetName = "Storage_offshore"
        try 
            XLSX.addsheet!(xf, SheetName)
        catch 
        end
        sheet = xf[SheetName]
        XLSX.writetable!(sheet,Offshore_storages_df; anchor_cell=XLSX.CellRef("A1")) # NOTE: if shorter df --> some rows of previous run might still be included in excel table. (not yet resolved nicely: https://felipenoris.github.io/XLSX.jl/stable/api/)
    end

    XLSX.openxlsx(system_data_file, mode="rw") do xf
        SheetName = "Storage_inland"
        try 
            XLSX.addsheet!(xf, SheetName)
        catch 
        end
        sheet = xf[SheetName]
        XLSX.writetable!(sheet,Inland_storages_df; anchor_cell=XLSX.CellRef("A1")) # NOTE: if shorter df --> some rows of previous run might still be included in excel table. (not yet resolved nicely: https://felipenoris.github.io/XLSX.jl/stable/api/)
    end

    return  Offshore_storages_df, Inland_storages_df 
end

function writing_pipeline_input_data(raw_file_gas, Centroids_df, Routing_nodes_df, Terminal_harbour_nodes_df, Offshore_nodes_df, Offshore_storages_df, Inland_storages_df, system_data_file)

    Raw_PipeSegments_gas_1 =  CSV.read(raw_file_gas, DataFrame)

    # eliminating double id- pipelines
    grouped = DataFrames.groupby(Raw_PipeSegments_gas_1, :node_id)
    counts_df = combine(grouped, nrow => :count)
    unique_node_ids = counts_df[counts_df.count .== 1, :node_id]
    Raw_PipeSegments_gas = filter(row -> row.node_id in unique_node_ids, Raw_PipeSegments_gas_1)

    NODE_ORIGIN =  Vector{String}(undef, length(Raw_PipeSegments_gas[:,"node_id"]))
    NODE_DESTINATION =  Vector{String}(undef, length(Raw_PipeSegments_gas[:,"node_id"]))

    for (index, s) in enumerate(Raw_PipeSegments_gas[:,"node_id"])
        o = match(r"'([^']*)'", s)
        NODE_ORIGIN[index] = o.captures[1]
        comma_index = findfirst(',', s)
        second_part = s[comma_index+1:end]
        first_quote_index = findfirst("'", second_part)[1]
        last_quote_index = findlast("'", second_part)[1]
        d = second_part[first_quote_index+1:last_quote_index-1]
        NODE_DESTINATION[index] = d
    end
    
    LAT_START =  Vector{Float64}(undef, length(Raw_PipeSegments_gas[:,"node_id"]))
    LAT_END = Vector{Float64}(undef, length(Raw_PipeSegments_gas[:,"node_id"]))
    LON_START =  Vector{Float64}(undef, length(Raw_PipeSegments_gas[:,"node_id"]))
    LON_END = Vector{Float64}(undef, length(Raw_PipeSegments_gas[:,"node_id"]))

    for (index, s) in enumerate(Raw_PipeSegments_gas[:,"lat"])
  
        # Remove the brackets by replacing them with an empty string
        s_clean = replace(s, '[' => "", ']' => "")
        
        # Split the string into parts using the comma as a delimiter
        parts = split(s_clean, ", ")
        
        # Convert the parts to Float64 and create a vector
        vector_lat = [parse(Float64, part) for part in parts]
        
        LAT_START[index] = vector_lat[1]
        LAT_END[index] = vector_lat[2]
    end

    for (index, s) in enumerate(Raw_PipeSegments_gas[:,"long"])
  
        # Remove the brackets by replacing them with an empty string
        s_clean = replace(s, '[' => "", ']' => "")
        
        # Split the string into parts using the comma as a delimiter
        parts = split(s_clean, ", ")
        
        # Convert the parts to Float64 and create a vector
        vector_lon = [parse(Float64, part) for part in parts]
        
        LON_START[index] = vector_lon[1]
        LON_END[index] = vector_lon[2]
    end

    # Existing pipelines from gas grid  
    Pipes_df_raw_gas_segments = DataFrame(
    Pipeline_id = ["$(Raw_PipeSegments_gas[i, "id"])_$(i)" for i in 1:length(Raw_PipeSegments_gas[:,"name"])], 
    Pipe_name = ["$(Raw_PipeSegments_gas[i, "name"])_$(i)" for i in 1:length(Raw_PipeSegments_gas[:,"name"])],
    Node_origin = NODE_ORIGIN,
    Node_destination = NODE_DESTINATION,
    Latitude_origin = LAT_START,
    Longitude_origin = LON_START,
    Latitude_destination = LAT_END,
    Longitude_destination = LON_END
    )


    non_uniques = nonunique(Pipes_df_raw_gas_segments[:,3:(end)])
    extract_uniques = .!non_uniques
    Pipes_df_raw_gas_segments = Pipes_df_raw_gas_segments[extract_uniques, 1:end]

    Pipes_df_raw_gas_segments = unique(Pipes_df_raw_gas_segments)

    ##################################################################################### # mainly for coarse grid
    # Remove some pipelines called "INET_N_240" - because those are not connecting emitters to the main grid
    Pipes_df_raw_gas_segments_2 = filter(row -> row.Node_destination != "INET_N_240", Pipes_df_raw_gas_segments) # removes one in the coarse scenario (by making it a standalone pipeline)
    Pipes_df_raw_gas_segments_3 = filter(row -> row.Node_origin != "INET_N_240", Pipes_df_raw_gas_segments_2) # removes one in the coarse scenario

    ##################################################################################### # mainly for coarse grid
    # Making sure that there are no standalone pipelines to which clusters can connect
    nodes = unique(vcat(Pipes_df_raw_gas_segments_3.Node_origin, Pipes_df_raw_gas_segments_3.Node_destination))
    node_to_idx = Dict(n => i for (i, n) in enumerate(nodes))
    g = Graph(length(nodes))
    edge_to_row = Dict{Tuple{Int,Int}, Int}()
    for (i, row) in enumerate(eachrow(Pipes_df_raw_gas_segments_3))
        u = node_to_idx[row.Node_origin]
        v = node_to_idx[row.Node_destination]
        add_edge!(g, u, v)
        edge_to_row[(u, v)] = i
        edge_to_row[(v, u)] = i  # since graph is undirected
    end
    rows_to_keep = Int[]
    components = connected_components(g)
    for comp in components
        if length(comp) > 2  # i.e., more than a single pipe
            # collect all edges within this component
            for u in comp, v in neighbors(g, u)
                if u < v  # to avoid duplicates
                    row_idx = get(edge_to_row, (u, v), nothing)
                    if row_idx !== nothing
                        push!(rows_to_keep, row_idx)
                    end
                end
            end
        end
    end
    filtered_df = Pipes_df_raw_gas_segments_3[unique(rows_to_keep), :]   
    all_rows = 1:nrow(Pipes_df_raw_gas_segments_3)
    rows_to_remove = setdiff(all_rows, unique(rows_to_keep))
    standalone_df = Pipes_df_raw_gas_segments_3[rows_to_remove, :] # this one should contain the INET_PL_1466_623? INET_PL_408_EE_0_154
    Pipes_df_raw_gas_segments = filtered_df
    # removing nodes of Routing_nodes_df that are related to stand alone pipelines 
    standalone_nodes = unique(vcat(standalone_df.Node_origin, standalone_df.Node_destination))
    filtered_routing_nodes = filter(row -> !(row.Node_name in standalone_nodes), Routing_nodes_df)
    Routing_nodes_df = filtered_routing_nodes
    #####################################################################################
    # Making sure that names of the nodes correspond to the routing renaming
    if detail_level == "coarse"
        for r in eachrow(Routing_nodes_df)
            Pipes_df_raw_gas_segments.Node_origin[(Pipes_df_raw_gas_segments[:, "Latitude_origin"] .== r["Lat"]) .& (Pipes_df_raw_gas_segments[:, "Longitude_origin"] .== r["Lon"])] .= r["Node_id"] 
            Pipes_df_raw_gas_segments.Node_destination[(Pipes_df_raw_gas_segments[:, "Latitude_destination"] .== r["Lat"]) .& (Pipes_df_raw_gas_segments[:, "Longitude_destination"] .== r["Lon"])] .= r["Node_id"]    
        end 
    else 
    end
    #####################################################################################
    # filtering out the nodes where the pipeline has a distance of 0 km (to avoid segmentations: connection of centroids to zero-length pipelines)

  
    Pipeline_names = DataFrame(
        Node_origin = Pipes_df_raw_gas_segments.Node_origin, 
        Node_destination = Pipes_df_raw_gas_segments.Node_destination)




    # ######################################################################################
    filtered_pipelines = filter(row -> row.Node_origin == row.Node_destination, Pipeline_names)
    filtered_nodes = filtered_pipelines[:, "Node_origin"] # Nodes that lead to pipelines of 0 distances 


    Routing_nodes_filtered_df = unique(filter(row -> row.Node_id ∉ filtered_nodes, Routing_nodes_df))
    # ######################################################################################






    # Pipelines connecting emitters (their node/cluster id (the latter)) to the closest existing gas pipeline node (filtered: meaning that the node belongs with certainty to a pipeline with a distance longer than 0 km)
    closest_E_R_nodes_lat, closest_E_R_nodes_lon, E_R_node_names = closest_node_2_node(Centroids_df, Routing_nodes_filtered_df)
    
    Pipes_df_raw_emitter_Rnode_segments = DataFrame(
        Pipeline_id = ["PL_$(Centroids_df[i,"Cluster"])_$(E_R_node_names[i])" for i in 1:length(E_R_node_names)],
        Pipe_name = ["PL_$(Centroids_df[i,"Cluster"])_$(E_R_node_names[i])" for i in 1:length(E_R_node_names)],
        Node_origin = ["$(Centroids_df[i,"Cluster"])" for i in 1:length(E_R_node_names)],
        Node_destination = ["$(E_R_node_names[i])" for i in 1:length(E_R_node_names)],
        Latitude_origin = Centroids_df[:,"Lat"],
        Longitude_origin = Centroids_df[:,"Lon"],
        Latitude_destination = closest_E_R_nodes_lat,
        Longitude_destination = closest_E_R_nodes_lon
        )
    Pipes_df_raw_emitter_Rnode_segments = unique(Pipes_df_raw_emitter_Rnode_segments)

    # Pipelines connected closest centroids to each other. 
    Centroids_df[:, "Node_id"] = Centroids_df[:, "Cluster"]
    if detail_level == "coarse"   # if coarse: connect the two closest centroids with each other 
        two_closest_C_C_nodes_lat, two_closest_C_C_nodes_lon, two_C_C_node_names = number_closest_node_2_node(Centroids_df, Centroids_df, 2)
        Pipes_df_raw_cluster2cluster_segments = build_pipes_df(Centroids_df, two_C_C_node_names, two_closest_C_C_nodes_lat, two_closest_C_C_nodes_lon)
        for pipe in Pipes_df_raw_cluster2cluster_segments[!, "Pipe_name"]
            for  pipe_rvs in Pipes_df_raw_cluster2cluster_segments[!, "Pipe_name"]
                if pipe_rvs .== pipe
                    delete!(Pipes_df_raw_cluster2cluster_segments, Pipes_df_raw_cluster2cluster_segments[:, "Pipe_name_rvs"] .== pipe_rvs)
                else
                    skip
                end
            end
        end
    else # if dense: connect only the closest centroids with each other 
        closest_C_C_nodes_lat, closest_C_C_nodes_lon, C_C_node_names = closest_node_2_node(Centroids_df, Centroids_df)
        Pipes_df_raw_cluster2cluster_segments = DataFrame(
            Pipeline_id = ["PL_$(Centroids_df[i,"Cluster"])_$(C_C_node_names[i])" for i in 1:length(C_C_node_names)],
            Pipe_name = ["PL_$(Centroids_df[i,"Cluster"])_$(C_C_node_names[i])" for i in 1:length(C_C_node_names)],
            Pipe_name_rvs = ["PL_$(C_C_node_names[i])_$(Centroids_df[i,"Cluster"])" for i in 1:length(C_C_node_names)],
            Node_origin = ["$(Centroids_df[i,"Cluster"])" for i in 1:length(C_C_node_names)],
            Node_destination = ["$(C_C_node_names[i])" for i in 1:length(C_C_node_names)],
            Latitude_origin = Centroids_df[:,"Lat"],
            Longitude_origin = Centroids_df[:,"Lon"],
            Latitude_destination = closest_C_C_nodes_lat,
            Longitude_destination = closest_C_C_nodes_lon
            )
    end


    for (Lat_o, Lon_o, Lat_d, Lon_d) in zip(Pipes_df_raw_cluster2cluster_segments[:, "Latitude_origin"], Pipes_df_raw_cluster2cluster_segments[:,"Longitude_origin"], Pipes_df_raw_cluster2cluster_segments[:, "Latitude_destination"], Pipes_df_raw_cluster2cluster_segments[:,"Longitude_destination"])
        P_o = (Lat_o, Lon_o)
        P_d = (Lat_d, Lon_d)
        distance = haversine_distance(P_o, P_d, 6372.8)
        if (distance > 40.0) .& (detail_level == "dense") # Only connect clusters if they are closer to each other than 40kms 
            delete!(Pipes_df_raw_cluster2cluster_segments, Pipes_df_raw_cluster2cluster_segments[:, "Latitude_origin"] .== Lat_o)
        elseif (distance > 80.0) .& (detail_level == "coarse") # Only connect clusters if they are closer to each other than 80kms 
            delete!(Pipes_df_raw_cluster2cluster_segments, Pipes_df_raw_cluster2cluster_segments[:, "Latitude_origin"] .== Lat_o)
        else
        end
    end



    Pipes_df_raw_cluster2cluster_segments = unique(Pipes_df_raw_cluster2cluster_segments)
    Pipes_df_raw_cluster2cluster_segments = select(Pipes_df_raw_cluster2cluster_segments, Not(:Pipe_name_rvs))

    ####################################################################################################################""
    # # Pipelines connecting emitters (their node/cluster id) to the closest other emitter 
    # closest_E_E_nodes_lat, closest_E_E_nodes_lon, E_E_node_names = closest_node_2_node(IndEmitters_df, IndEmitters_df)

    # Pipes_df_raw_emitter_segments = DataFrame(
    #     Pipeline_id = ["PL_$(IndEmitters_df[i,"Node_id"])_$(E_E_node_names[i])" for i in 1:length(E_E_node_names)],
    #     Pipe_name = ["PL_$(IndEmitters_df[i,"Node_id"])_$(E_E_node_names[i])" for i in 1:length(E_E_node_names)],
    #     Node_origin = IndEmitters_df[:,"Node_id"],
    #     Node_destination = ["$(E_E_node_names[i])" for i in 1:length(E_E_node_names)],
    #     Latitude_origin = IndEmitters_df[:,"Lat"],
    #     Longitude_origin = IndEmitters_df[:,"Lon"],
    #     Latitude_destination = closest_E_E_nodes_lat,
    #     Longitude_destination = closest_E_E_nodes_lon
    #     )
    # Pipes_df_raw_emitter_segments = unique(Pipes_df_raw_emitter_segments)
    #######################################################################################################################

    # Pipelines connecting harbour terminals to the closest existing gas pipeline node 
    closest_T_R_nodes_lat, closest_T_R_nodes_lon, T_R_node_names = closest_node_2_node(Terminal_harbour_nodes_df, Routing_nodes_filtered_df)

    Pipes_df_raw_terminal_onshore_segments = DataFrame(
    Pipeline_id = ["PL_$(Terminal_harbour_nodes_df[i, "Node_id"])_$(T_R_node_names[i])" for i in 1:length(T_R_node_names)],
    Pipe_name = ["PL_$(Terminal_harbour_nodes_df[i,"Node_id"])_$(T_R_node_names[i])" for i in 1:length(T_R_node_names)],
    Node_origin = Terminal_harbour_nodes_df[:,"Node_id"],
    Node_destination = ["$(T_R_node_names[i])" for i in 1:length(T_R_node_names)],
    Latitude_origin = Terminal_harbour_nodes_df[:,"Lat"],
    Longitude_origin = Terminal_harbour_nodes_df[:,"Lon"],
    Latitude_destination = closest_T_R_nodes_lat,
    Longitude_destination = closest_T_R_nodes_lon
    )

    # Pipelines connecting harbour terminals to closest offshore node 
    closest_T_O_nodes_lat, closest_T_O_nodes_lon, T_O_node_names = closest_node_2_node(Terminal_harbour_nodes_df, Offshore_nodes_df)

    Pipes_df_raw_terminal_offshore_segments = DataFrame(
    Pipeline_id = ["PL_$(Terminal_harbour_nodes_df[i, "Node_id"])_$(T_O_node_names[i])" for i in 1:length(T_O_node_names)],
    Pipe_name = ["PL_$(Terminal_harbour_nodes_df[i,"Node_id"])_$(T_O_node_names[i])" for i in 1:length(T_O_node_names)],
    Node_origin = Terminal_harbour_nodes_df[:,"Node_id"],
    Node_destination = ["$(T_O_node_names[i])" for i in 1:length(T_O_node_names)],
    Latitude_origin = Terminal_harbour_nodes_df[:,"Lat"],
    Longitude_origin = Terminal_harbour_nodes_df[:,"Lon"],
    Latitude_destination = closest_T_O_nodes_lat,
    Longitude_destination = closest_T_O_nodes_lon
    )

    # Pipelines connecting offshore storage nodes to closest offshore node 
    closest_S_O_nodes_lat, closest_S_O_nodes_lon, S_O_node_names = closest_node_2_node(Offshore_storages_df, Offshore_nodes_df)


    Pipes_df_raw_storage_offshore_segments = DataFrame(
        Pipeline_id = ["PL_$(Offshore_storages_df[i, "Node_id"])_$(S_O_node_names[i])" for i in 1:length(S_O_node_names)],
        Pipe_name = ["PL_$(Offshore_storages_df[i,"Node_id"])_$(S_O_node_names[i])" for i in 1:length(S_O_node_names)],
        Node_origin = Offshore_storages_df[:,"Node_id"],
        Node_destination = ["$(S_O_node_names[i])" for i in 1:length(S_O_node_names)],
        Latitude_origin = Offshore_storages_df[:,"Lat"],
        Longitude_origin = Offshore_storages_df[:,"Lon"],
        Latitude_destination = closest_S_O_nodes_lat,
        Longitude_destination = closest_S_O_nodes_lon
        )
    
   


    # Pipelines connecting inland storage nodes to closest routing node 
    closest_S_I_nodes_lat, closest_S_I_nodes_lon, S_I_node_names = closest_node_2_node(Inland_storages_df, Routing_nodes_filtered_df)


    Pipes_df_raw_storage_inland_segments = DataFrame(
        Pipeline_id = ["PL_$(Inland_storages_df[i, "Node_id"])_$(S_I_node_names[i])" for i in 1:length(S_I_node_names)],
        Pipe_name = ["PL_$(Inland_storages_df[i,"Node_id"])_$(S_I_node_names[i])" for i in 1:length(S_I_node_names)],
        Node_origin = Inland_storages_df[:,"Node_id"],
        Node_destination = ["$(S_I_node_names[i])" for i in 1:length(S_I_node_names)],
        Latitude_origin = Inland_storages_df[:,"Lat"],
        Longitude_origin = Inland_storages_df[:,"Lon"],
        Latitude_destination = closest_S_I_nodes_lat,
        Longitude_destination = closest_S_I_nodes_lon
        )
    
    #Pipelines connecting offshore storage nodes 
    Pipes_df_raw_offshore_node_segments = DataFrame(
        Pipeline_id = ["PL_$(Offshore_nodes_df[i, "Node_id"])_$(Offshore_nodes_df[i+1, "Node_id"])" for i in 1:(length(Offshore_nodes_df[:, "Node_id"])-1)],
        Pipe_name = ["PL_$(Offshore_nodes_df[i, "Node_name"])_$(Offshore_nodes_df[i+1, "Node_name"])" for i in 1:(length(Offshore_nodes_df[:, "Node_id"])-1)],
        Node_origin = Offshore_nodes_df[1:(end-1),"Node_id"],
        Node_destination = Offshore_nodes_df[2:(end),"Node_id"],
        Latitude_origin = Offshore_nodes_df[1:(end-1),"Lat"],
        Longitude_origin = Offshore_nodes_df[1:(end-1),"Lon"],
        Latitude_destination = Offshore_nodes_df[2:(end),"Lat"],
        Longitude_destination = Offshore_nodes_df[2:(end),"Lon"]
        )

    closest_SO_SO_nodes_lat, closest_SO_SO_nodes_lon, SO_SO_node_names  = number_closest_node_2_node(Offshore_storages_df, Offshore_storages_df, 4)
    Pipes_df_raw_storage_offshore = build_pipes_df(Offshore_storages_df, SO_SO_node_names, closest_SO_SO_nodes_lat, closest_SO_SO_nodes_lon)
    Pipes_df_raw_storage_offshore2offshore_segments = unique(Pipes_df_raw_storage_offshore)
    Pipes_df_raw_storage_offshore2offshore_segments = select(Pipes_df_raw_storage_offshore2offshore_segments, Not(:Pipe_name_rvs))
  
    
    for pipe in Pipes_df_raw_storage_offshore[!, "Pipe_name"] 
        for  pipe_rvs in Pipes_df_raw_storage_offshore[!, "Pipe_name"]
            if pipe_rvs .== pipe
                delete!(Pipes_df_raw_storage_offshore, Pipes_df_raw_storage_offshore[:, "Pipe_name_rvs"] .== pipe_rvs)
            else
                skip
            end
        end
    end
    delete!(Pipes_df_raw_storage_offshore, Pipes_df_raw_storage_offshore[:, "Node_origin"] .== "So4") # deleting connections from Italy (goes over main continent)
    Pipes_df_raw_storage_offshore2offshore_segments = unique(Pipes_df_raw_storage_offshore)
    Pipes_df_raw_storage_offshore2offshore_segments = select(Pipes_df_raw_storage_offshore2offshore_segments, Not(:Pipe_name_rvs))

    # for (i, row) in enumerate(eachrow(Pipes_df_raw_storage_offshore2offshore_segments))
    #     line_coords = [row.Longitude_origin row.Latitude_origin; row.Longitude_destination row.Latitude_destination]
    #     B = inecos_line(D, line_coords::Matrix{Float64}) # Bool 
    #     if B .== true
    #         delete!(Pipes_df_raw_storage_offshore2offshore_segments, i)  
    #         print("drop_SO_line") 
    #     else 
    #         skip
    #     end
    # end
      # Manually added pipeline segments
    # Antwerp - Diest
    # Antwerp: 51.29272515	4.311498277 = C20 
    # Diest: 51.10021383	5.068412386 = C18


    Pipes_df_manual_1 = DataFrame(
        Pipeline_id = ["PL_C20_C18"],
        Pipe_name = ["PL_Antwerp_Diest"],
        Node_origin = ["C20"],
        Node_destination = ["C18"],
        Latitude_origin = [Centroids_df[Centroids_df[:, "Cluster"] .=="C20","Lat"][1]],
        Longitude_origin = [Centroids_df[Centroids_df[:, "Cluster"] .=="C20","Lon"][1]],
        Latitude_destination = [Centroids_df[Centroids_df[:, "Cluster"] .=="C18","Lat"][1]],
        Longitude_destination = [Centroids_df[Centroids_df[:, "Cluster"] .=="C18","Lon"][1]]
        )
    # Cologne - Helmond (part 1 of Delta Rhine)
    # Cologne: 50.99700587	6.92459644 = C88

    Pipes_df_manual_2 = DataFrame(
        Pipeline_id = ["PL_C88_INET_N_863"],
        Pipe_name = ["PL_Cologne_Helmond"],
        Node_origin = ["C88"],
        Node_destination = ["INET_N_863"],
        Latitude_origin = [Centroids_df[Centroids_df[:, "Cluster"] .=="C88","Lat"][1]],
        Longitude_origin = [Centroids_df[Centroids_df[:, "Cluster"] .=="C88","Lon"][1]],
        Latitude_destination = [Routing_nodes_filtered_df[Routing_nodes_filtered_df[:, "Node_id"] .=="INET_N_863","Lat"][1]],
        Longitude_destination = [Routing_nodes_filtered_df[Routing_nodes_filtered_df[:, "Node_id"] .=="INET_N_863","Lon"][1]]
        )
    # Tilburg - Helmond (part 2 of Delta Rhine)
    # Tilburg: 51.6107966	4.9950676

    Pipes_df_manual_3 = DataFrame(
        Pipeline_id = ["PL_C429_INET_N_863"],
        Pipe_name = ["PL_Tilburg_Helmond"],
        Node_origin = ["C429"],
        Node_destination = ["INET_N_863"],
        Latitude_origin = [Centroids_df[Centroids_df[:, "Cluster"] .=="C429","Lat"][1]],
        Longitude_origin = [Centroids_df[Centroids_df[:, "Cluster"] .=="C429","Lon"][1]],
        Latitude_destination = [Routing_nodes_filtered_df[Routing_nodes_filtered_df[:, "Node_id"] .=="INET_N_863","Lat"][1]],
        Longitude_destination = [Routing_nodes_filtered_df[Routing_nodes_filtered_df[:, "Node_id"] .=="INET_N_863","Lon"][1]]
        )
    
    # Brugges - ZB- cluster 
    # Brugges: 51.22098812	3.230582912 = C26

    Pipes_df_manual_4 = DataFrame(
        Pipeline_id = ["PL_C26_INET_N_912"],
        Pipe_name = ["PL_ZB_Brugges"],
        Node_origin = ["C26"],
        Node_destination = ["INET_N_912"],
        Latitude_origin = [Centroids_df[Centroids_df[:, "Cluster"] .=="C26","Lat"][1]],
        Longitude_origin = [Centroids_df[Centroids_df[:, "Cluster"] .=="C26","Lon"][1]],
        Latitude_destination = [Routing_nodes_filtered_df[Routing_nodes_filtered_df[:, "Node_id"] .=="INET_N_912","Lat"][1]],
        Longitude_destination = [Routing_nodes_filtered_df[Routing_nodes_filtered_df[:, "Node_id"] .=="INET_N_912","Lon"][1]]
        )

    # Left of Amiens to English Channel 
    # ENCHANNEL :50.06475255	1.43429425 = C251
    # Amiens:  C258
    Pipes_df_manual_5 = DataFrame(
        Pipeline_id = ["PL_C251_C258"],
        Pipe_name = ["PL_ENChannel_leftAmien"],
        Node_origin = ["C251"],
        Node_destination = ["C258"],
        Latitude_origin = [Centroids_df[Centroids_df[:, "Cluster"] .=="C251","Lat"][1]],
        Longitude_origin = [Centroids_df[Centroids_df[:, "Cluster"] .=="C251","Lon"][1]],
        Latitude_destination = [Centroids_df[Centroids_df[:, "Cluster"] .=="C258","Lat"][1]],
        Longitude_destination = [Centroids_df[Centroids_df[:, "Cluster"] .=="C258","Lon"][1]]
        )
    # 1) Pipes_df_raw_gas_segments
    # 2) Pipes_df_raw_emitter_segments
    # 3) Pipes_df_raw_terminal_onshore_segments     --> this is about connecting harbour segments to inland routing node
    # 4) Pipes_df_raw_terminal_offshore_segments    --> this is about connecting harbour segments to offshore line
    # 5) Pipes_df_raw_storage_offshore_segments
    # 6) Pipes_df_raw_storage_inland_segments
    # 7) Pipes_df_raw_offshore_node_segments 
    # 8) Pipes_df_raw_cluster2cluster_segments
    # 9) Pipes_df_raw_storage_offshore2offshore_segments
    
    Pipes_df =   vcat(vcat(vcat(vcat(vcat(vcat(vcat(vcat(vcat(vcat(vcat(vcat(vcat(
        Pipes_df_raw_gas_segments, 
        Pipes_df_raw_terminal_onshore_segments), 
        Pipes_df_raw_terminal_offshore_segments), 
        Pipes_df_raw_storage_offshore_segments), 
        Pipes_df_raw_storage_inland_segments), 
        Pipes_df_raw_offshore_node_segments), 
        Pipes_df_raw_emitter_Rnode_segments), 
        Pipes_df_raw_cluster2cluster_segments),
        Pipes_df_raw_storage_offshore2offshore_segments),
        Pipes_df_manual_1), 
        Pipes_df_manual_2), 
        Pipes_df_manual_3),
        Pipes_df_manual_4),
        Pipes_df_manual_5)

    Pipes_df[!,"Id_qgis"] = [i for i in 1:1:length(Pipes_df[!,"Pipeline_id"])]
    Pipes_df = filter(row -> row.Node_origin != row.Node_destination, Pipes_df)
    Pipes_df[!, "Distance_km"] = [try maximum([0.1, haversine_distance((Pipes_df[i, "Latitude_origin"], Pipes_df[i, "Longitude_origin"]), (Pipes_df[i, "Latitude_destination"], Pipes_df[i, "Longitude_destination"]), 6372.8)]) catch missing  end for i in 1:1:length(Pipes_df[:,1])]

    # Extract latitude and longitude
    latitudes = Pipes_df[:, "Latitude_destination"]
    longitudes = Pipes_df[:, "Longitude_destination"]

    gc = Geocoder()   
    Country_code_pipe_dest = [decode(gc, SA[latitudes[i], longitudes[i]])[2] for i in 1:length(latitudes)]
    Pipes_df[:, "NUTS0"] = Country_code_pipe_dest
   
    XLSX.openxlsx(system_data_file, mode="rw") do xf
        SheetName = "Pipelines"
        try 
            XLSX.addsheet!(xf, SheetName)
        catch 
        end
        sheet = xf[SheetName]
        XLSX.writetable!(sheet,Pipes_df; anchor_cell=XLSX.CellRef("A1")) # NOTE: if shorter df --> some rows of previous run might still be included in excel table. (not yet resolved nicely: https://felipenoris.github.io/XLSX.jl/stable/api/)
        print("$(SheetName) written to excel")
    end

    print(" All unique pipelines = $(allunique(Pipes_df))")
    # connecting each terminal to k closest storage locations
    # k = 5
    # STline_tuple = closests_terminal_storage!(Offshore_storages_df, Terminal_harbour_nodes_df, k)

    # Pipes_df_raw_storage_segments = DataFrame(
    #     Pipeline_id = reshape(["PL_$(Terminal_harbour_nodes_df[i,"Node_id"])_$(STline_tuple[i][j][4])" for i in 1:length(Terminal_harbour_nodes_df[:,"Node_id"]), j in 1:k],:),
    #     Pipe_name = reshape(["PL_$(Terminal_harbour_nodes_df[i,"Node_id"])_$(STline_tuple[i][j][4])" for i in 1:length(Terminal_harbour_nodes_df[:,"Node_id"]), j in 1:k],:),
    #     Node_origin = repeat(Terminal_harbour_nodes_df[:,"Node_id"], k),
    #     Node_destination = reshape([STline_tuple[i][j][4] for i in 1:length(Terminal_harbour_nodes_df[:,"Node_id"]), j in 1:k],:),
    #     Latitude_origin = repeat(Terminal_harbour_nodes_df[:,"Lat"], k),
    #     Longitude_origin =  repeat(Terminal_harbour_nodes_df[:,"Lon"], k),
    #     Latitude_destination = reshape([STline_tuple[i][j][2] for i in 1:length(Terminal_harbour_nodes_df[:,"Node_id"]), j in 1:k],:),
    #     Longitude_destination = reshape([STline_tuple[i][j][3] for i in 1:length(Terminal_harbour_nodes_df[:,"Node_id"]), j in 1:k],:)
    #     )


    return Pipes_df
end 

function closest_node_2_node(IndEmitters_df, Routing_nodes_df)
    closest_nodes_lat = []
    closest_nodes_lon = []
    node_names = []
    distances = []
    
    for (lat_e, lon_e) in zip(IndEmitters_df[:, "Lat"], IndEmitters_df[:, "Lon"])
        min_distance = Inf
        global P_e = (lat_e, lon_e)
        node_names_temp = []
        distances_temp = []
        nodes_lat_temp = []
        nodes_lon_temp = []

        for (lat_n, lon_n, R_name) in zip(Routing_nodes_df[:, "Lat"], Routing_nodes_df[:, "Lon"], Routing_nodes_df[:, "Node_id"])
            P_n = (lat_n, lon_n)
            distance = maximum([0.0, haversine_distance(P_e, P_n, 6372.8)])
            push!(node_names_temp, R_name)
            push!(distances_temp, distance)
            push!(nodes_lat_temp, lat_n)
            push!(nodes_lon_temp, lon_n)
        end
        non_zero_indices = findall(x -> x > 0, distances_temp)
        min_index = argmin(distances_temp[non_zero_indices])
        min_distance = distances_temp[non_zero_indices][min_index]
        min_distance_adj = maximum([0.1, min_distance])
        min_original_index = non_zero_indices[min_index]

        push!(closest_nodes_lat, nodes_lat_temp[min_original_index])
        push!(closest_nodes_lon, nodes_lon_temp[min_original_index])
        push!(node_names, node_names_temp[min_original_index])
        push!(distances, min_distance_adj)
    end
    
    return closest_nodes_lat, closest_nodes_lon, node_names
end

function number_closest_node_2_node(IndEmitters_df, Routing_nodes_df, closest_number)
    two_closest_nodes_lat = []
    two_closest_nodes_lon = []
    two_node_names = []
    two_distances = []

    for (lat_e, lon_e) in zip(IndEmitters_df[:, "Lat"], IndEmitters_df[:, "Lon"])
        global P_e = (lat_e, lon_e)
        node_names_temp = []
        distances_temp = []
        distances_temp_correct = []
        nodes_lat_temp = []
        nodes_lon_temp = []

        for (lat_n, lon_n, R_name) in zip(Routing_nodes_df[:, "Lat"], Routing_nodes_df[:, "Lon"], Routing_nodes_df[:, "Node_id"])
            global P_n = (lat_n, lon_n)
            distance = maximum([0.0, haversine(P_e, P_n, 6372.8)]) # orginal script 
            distance_correct = maximum([0.0, haversine_distance(P_e, P_n, 6372.8)]) # right code  
            push!(node_names_temp, R_name)
            push!(distances_temp, distance)
            push!(distances_temp_correct, distance_correct)
            push!(nodes_lat_temp, lat_n)
            push!(nodes_lon_temp, lon_n)
        end
        non_zero_indices = findall(x -> x > 0.0, distances_temp)
        distances_temp_adj = [maximum([0.1, distances_temp[non_zero_indices][i]]) for i in 1:length(distances_temp[non_zero_indices])]
        distances_temp_correct_adj = distances_temp_correct[non_zero_indices]
        nodes_lat_temp_adj = nodes_lat_temp[non_zero_indices]
        nodes_lon_temp_adj = nodes_lon_temp[non_zero_indices]
        node_names_temp_adj = node_names_temp[non_zero_indices]
        sorted_indices = sortperm(distances_temp_adj)
        closest_two_indices = sorted_indices[1:closest_number]

        push!(two_closest_nodes_lat, [nodes_lat_temp_adj[i] for i in closest_two_indices])
        push!(two_closest_nodes_lon, [nodes_lon_temp_adj[i] for i in closest_two_indices])
        push!(two_node_names, [node_names_temp_adj[i] for i in closest_two_indices])
        push!(two_distances, [distances_temp_correct_adj[i] for i in closest_two_indices])
    end

    return two_closest_nodes_lat, two_closest_nodes_lon, two_node_names, two_distances
end

function build_pipes_df(Offshore_storages_df, n_SO_SO_node_names, n_SO_SO_nodes_lat, n_SO_SO_nodes_lon)
    rows = []

    for i in 1:nrow(Offshore_storages_df)
        origin_id = Offshore_storages_df[i, "Node_id"]
        origin_lat = Offshore_storages_df[i, "Lat"]
        origin_lon = Offshore_storages_df[i, "Lon"]

        for j in 1:length(n_SO_SO_node_names[i])
            dest_id = n_SO_SO_node_names[i][j]
            dest_lat = n_SO_SO_nodes_lat[i][j]
            dest_lon = n_SO_SO_nodes_lon[i][j]

            push!(rows, (
                Pipeline_id = "PL_$(origin_id)_$(dest_id)",
                Pipe_name = "PL_$(origin_id)_$(dest_id)",
                Pipe_name_rvs = "PL_$(dest_id)_$(origin_id)",
                Node_origin = origin_id,
                Node_destination = dest_id,
                Latitude_origin = origin_lat,
                Longitude_origin = origin_lon,
                Latitude_destination = dest_lat,
                Longitude_destination = dest_lon
            ))
        end
    end

    return DataFrame(rows)
end



# function closest_node_2_node(IndEmitters_df, Routing_nodes_df)
#     closest_nodes_lat = []
#     closest_nodes_lon = []
#     node_names = []
#     distances = []
    
#     for (lat_e, lon_e) in zip(IndEmitters_df[:, "Lat"], IndEmitters_df[:, "Lon"])
#         min_distance = Inf
#         global P_e = (lat_e, lon_e)

#         for (lat_n, lon_n, R_name) in zip(Routing_nodes_df[:, "Lat"], Routing_nodes_df[:, "Lon"], Routing_nodes_df[:, "Node_id"])
#             P_n = (lat_n, lon_n)
#             distance = haversine(P_e, P_n, 6372.8)
#             if distance == 0 
#                 skip
#             elseif distance < min_distance
#                 min_distance = distance
#                 global closest_node_lat = lat_n
#                 global closest_node_lon = lon_n 
#                 global node_name = R_name
#             end
#         end
        
#         push!(closest_nodes_lat, closest_node_lat[1])
#         push!(closest_nodes_lon, closest_node_lon[1])
#         push!(node_names, node_name)
#         push!(distances, min_distance[1])
#     end
    
#     return closest_nodes_lat, closest_nodes_lon, node_names
# end

function closests_terminal_storage!(Offshore_storages_df, Terminal_harbour_nodes_df, k=5)
    distances = []
    STline_tuple = []
    
    for (lat_t, lon_t, T_id) in zip(Terminal_harbour_nodes_df[:, "Lat"], Terminal_harbour_nodes_df[:, "Lon"], Terminal_harbour_nodes_df[:, "Node_id"])
        distances = []
        global P_t = (lat_t, lon_t)

        for (lat_s, lon_s, S_id) in zip(Offshore_storages_df[:, "Lat"], Offshore_storages_df[:, "Lon"], Offshore_storages_df[:, "Node_id"])
            P_s = (lat_s, lon_s)
            distance = haversine_distance(P_s, P_t, 6372.8)
            push!(distances, (distance, lat_s, lon_s, S_id))
        end
        sorted_distances = sort(distances, by=x->x[1])
        closest_nodes = sorted_distances[1:k]
        push!(STline_tuple, closest_nodes)
    end
    
    return STline_tuple
end


function inecos(D, lon, lat)
    global B = false
    iswithin(bbox, lon, lat) = (lon >= bbox[1] && lon <= bbox[2] && lat >= bbox[3] && lat <= bbox[4])
    for k = 1:length(D)
        !iswithin(D[k].bbox, lon, lat) && continue
        r = gmtselect([lon lat], polygon=D[k])
        if (!isempty(r))
            println("Point falls inside polygon $(k)")
            B = true
            break
        end
    end
    nothing
    return B
end

    # function inecos_margin(D, lon, lat, margin_km=50.0)
    #     global B = false
    #     iswithin(bbox, lon, lat) = (lon >= bbox[1] && lon <= bbox[2] && lat >= bbox[3] && lat <= bbox[4])
    
    #     for k = 1:length(D)
    #         !iswithin(D[k].bbox, lon, lat) && continue
    #         r = gmtselect([lon lat], polygon=D[k])
    #         if (!isempty(r))
    #             println("Point falls inside polygon $(k)")
    #             B = true
    #             break
    #         elseif point_within_margin(lon, lat, D[k].polygon, margin_km)
    #             println("Point is within margin $(margin_km) km of polygon $(k)")
    #             B = true
    #             break
    #         end
    #     end
    #     return B
    # end


function inecos_line(D, line_coords::Matrix{Float64})
    global B = false
    # Helper: check if line bbox overlaps polygon bbox (for early rejection)
    function overlaps_bbox(line_bbox, poly_bbox)
        return !(line_bbox[2] < poly_bbox[1] || line_bbox[1] > poly_bbox[2] || 
                 line_bbox[4] < poly_bbox[3] || line_bbox[3] > poly_bbox[4])
    end

    # Compute bounding box of the input line
    line_bbox = [minimum(line_coords[:,1]), maximum(line_coords[:,1]),
                 minimum(line_coords[:,2]), maximum(line_coords[:,2])]

    for k = 1:length(D)
        poly = D[k]
        poly_bbox = poly.bbox
        overlaps_bbox(line_bbox, poly_bbox) || continue

        # Check intersection using GMT's gmtselect (pass line as multi-point line)
        r = gmtselect(line_coords, polygon=poly)
        if !isempty(r)
            println("Line intersects polygon $(k)")
            B = true
            break
        end
    end
    return B
end

function haversine_distance((lat1,lon1), (lat2, lon2), r2)
    # Convert latitude and longitude from degrees to radians
    lon1, lat1, lon2, lat2 = deg2rad.([lon1, lat1, lon2, lat2])

    # Radius of the Earth in kilometers
    r = 6371.0

    # Differences between points
    dlon = lon2 - lon1
    dlat = lat2 - lat1

    # Haversine formula
    a = sin(dlat / 2)^2 + cos(lat1) * cos(lat2) * sin(dlon / 2)^2
    c = 2 * atan(sqrt(a) / sqrt(1 - a))  # `atan2` can be replaced with `atan` and the quotient

    # Distance in kilometers
    distance = r * c
    return distance
end

# function haversine_distance(lon1, lat1, lon2, lat2)
#     # Convert latitude and longitude from degrees to radians
#     lon1, lat1, lon2, lat2 = deg2rad.([lon1, lat1, lon2, lat2])

#     # Radius of the Earth in kilometers
#     r = 6371.0

#     # Differences between points
#     dlon = lon2 - lon1
#     dlat = lat2 - lat1

#     # Haversine formula
#     a = sin(dlat / 2)^2 + cos(lat1) * cos(lat2) * sin(dlon / 2)^2
#     c = 2 * atan(sqrt(a) / sqrt(1 - a))  # `atan2` can be replaced with `atan` and the quotient

#     # Distance in kilometers
#     distance = r * c
#     return distance
# end


function point_inland_outside_margin(lon, lat, D, margin_km)
    global B = true
    for i in 1:length(D)
        for j in 1:length(D[i]) - 1
            p1 = D[i][j]
            p2 = D[i][j+1]

            dist_to_segment = haversine_distance((p2[1], p1[1]), (lat, lon), 6372.3)
            if dist_to_segment <= margin_km
                B = false
                break
            end
        end
    end
    return B
end


function transform_value_storage_cap(val)
    try
        if val == ""
            return 100.0 # Assuming total capacity of 100 Mton if no value specified --> will devided by 20 yrs. so yearly capacity of 5 MtCO2pa
        elseif startswith(val, ">")
            return parse(Float64, val[2:end]) .+ 100.0 
        elseif startswith(val, "<")
            return parse(Float64, val[2:end]) 
        else
            return parse(Float64, val)
        end
    catch 
        return 100.0
    end
end





function clustering_DBSCAN(IndEmitters_df, max_distance)

    coordinates = convert(Matrix{Float64}, hcat(IndEmitters_df.Lat, IndEmitters_df.Lon)')
    min_samples = 1  # Minimum points to form a cluster
    
    # Run DBSCAN
    result = dbscan(coordinates, max_distance; metric=Euclidean())
    # Assign cluster labels to DataFrame
    IndEmitters_df.Cluster_julia = ["C$(cluster)" for cluster in result.assignments]
    


    # Centroids of each cluster (mean of points in each cluster)
    Centroids_df = DataFrame()
    for c in unique(result.assignments)
        if c != 0  # Skip noise points (cluster 0)
            cluster_points = IndEmitters_df[result.assignments .== c, [:Lat, :Lon]]
            centroid = mean.(eachcol(cluster_points))  # Compute mean Lat and Lon
            push!(Centroids_df, (; Lat=centroid[1], Lon=centroid[2], Cluster="C$(c)"))
        end
    end
    
    # println("\nCentroids:")
    # println(Centroids_df)
return Centroids_df, IndEmitters_df
end



function get_no_cc_base_name(name, suffixes)
    for suffix in suffixes
        if endswith(name, suffix)
            new_name = name[1:end - length(suffix)]
            if endswith(new_name, "-")
                 return  new_name[1:end - 1]
            else
                return new_name
            end
        end
    end
    return name
end


function get_additional_capex_cc_costs(AidRES_adj_model_configuration, name, suffixes, config, Add_capex_cc_cost_df)
    additional_cc_capex_cost = 0.0
    for suffix in suffixes
        if endswith(name, suffix)
            product_id =  Any[AidRES_adj_model_configuration[AidRES_adj_model_configuration[:, "configuration_id"] .== config, "product_id"][1]]
            additional_cc_capex_cost = Add_capex_cc_cost_df[Add_capex_cc_cost_df[:, "Product_names"] .== product_id, "Additional_capex_cc_cost"][1]
            break
        else 
            additional_cc_capex_cost = 0.0
        end
    end
    return additional_cc_capex_cost
end



function country_coordinate_transform(df)

country_epsg_map = Dict(
    "Albania" => "EPSG:25834",
    "Andorra" => "EPSG:25831",
    "Austria" => "EPSG:25833",
    "Belarus" => "EPSG:25836",  # not ETRS89 officially, approximate
    "Belgium" => "EPSG:25831",
    "Bosnia and Herzegovina" => "EPSG:25834",
    "Bulgaria" => "EPSG:25835",
    "Croatia" => "EPSG:25833",
    "Cyprus" => "EPSG:25836",
    "Czech Republic" => "EPSG:25833",
    "Denmark" => "EPSG:25832",
    "Estonia" => "EPSG:25835",
    "Finland" => "EPSG:25835",
    "France" => "EPSG:25831",
    "Germany" => "EPSG:25832",
    "Greece" => "EPSG:25834",
    "Hungary" => "EPSG:25834",
    "Iceland" => "EPSG:3057",  # ISN2004 / LAEA Iceland
    "Ireland" => "EPSG:2157",  # Irish Transverse Mercator
    "Italy" => "EPSG:25832",
    "Kosovo" => "EPSG:25834",
    "Latvia" => "EPSG:25835",
    "Liechtenstein" => "EPSG:25832",
    "Lithuania" => "EPSG:25835",
    "Luxembourg" => "EPSG:25831",
    "Malta" => "EPSG:25833",
    "Moldova" => "EPSG:3844",  # Moldref99 / UTM zone 35N
    "Monaco" => "EPSG:25831",
    "Montenegro" => "EPSG:25834",
    "Netherlands" => "EPSG:25831",
    "North Macedonia" => "EPSG:25834",
    "Norway" => "EPSG:25833",  # UTM 33N mostly
    "Poland" => "EPSG:25834",
    "Portugal" => "EPSG:25829",
    "Romania" => "EPSG:25835",
    "Russia" => "EPSG:25838",  # western Russia
    "San Marino" => "EPSG:25832",
    "Serbia" => "EPSG:25834",
    "Slovakia" => "EPSG:25834",
    "Slovenia" => "EPSG:25833",
    "Spain" => "EPSG:25830",
    "Sweden" => "EPSG:25833",
    "Switzerland" => "EPSG:25832",
    "Turkey" => "EPSG:25836",  # west Turkey
    "Ukraine" => "EPSG:25836",
    "United Kingdom" => "EPSG:27700"  # British National Grid
)
# unique(CO2SToP_carbon_storage_projects[:, "Projection_Info"])

country_lcc_projection_map = Dict(
    "Albania" => "+proj=lcc +lat_1=39 +lat_2=42 +lat_0=40.5 +lon_0=20 +ellps=GRS80 +units=m +no_defs",
    "Andorra" => "+proj=lcc +lat_1=41 +lat_2=43 +lat_0=42 +lon_0=1.6 +ellps=GRS80 +units=m +no_defs",
    "Austria" => "+proj=lcc +lat_1=46 +lat_2=49 +lat_0=47.5 +lon_0=13.3 +ellps=GRS80 +units=m +no_defs",
    "Belarus" => "+proj=lcc +lat_1=52 +lat_2=54 +lat_0=53 +lon_0=28 +ellps=GRS80 +units=m +no_defs",
    "Belgium" => "+proj=lcc +lat_1=49.8333 +lat_2=51.1667 +lat_0=50.5 +lon_0=4.367 +ellps=intl +towgs84=106.87,-52.30,103.72 +units=m +no_defs",
    "Bosnia and Herzegovina" => "+proj=lcc +lat_1=42 +lat_2=45 +lat_0=43.5 +lon_0=18 +ellps=GRS80 +units=m +no_defs",
    "Bulgaria" => "+proj=lcc +lat_1=41 +lat_2=44 +lat_0=42.5 +lon_0=25 +ellps=GRS80 +units=m +no_defs",
    "Croatia" => "+proj=lcc +lat_1=43.5 +lat_2=46.5 +lat_0=45 +lon_0=16.5 +ellps=GRS80 +units=m +no_defs",
    "Cyprus" => "+proj=lcc +lat_1=34 +lat_2=36 +lat_0=35 +lon_0=33 +ellps=GRS80 +units=m +no_defs",
    "Czech Republic" => "+proj=lcc +lat_1=48.5 +lat_2=51 +lat_0=49.7 +lon_0=15.5 +ellps=GRS80 +units=m +no_defs",
    "Denmark" => "+proj=lcc +lat_1=55 +lat_2=58 +lat_0=56.5 +lon_0=10 +ellps=GRS80 +units=m +no_defs",
    "Estonia" => "+proj=lcc +lat_1=57 +lat_2=59 +lat_0=58 +lon_0=25.5 +ellps=GRS80 +units=m +no_defs",
    "Finland" => "+proj=lcc +lat_1=60 +lat_2=68 +lat_0=64 +lon_0=26 +ellps=GRS80 +units=m +no_defs",
    "France" => "+proj=lcc +lat_1=44 +lat_2=49 +lat_0=46.5 +lon_0=3 +ellps=GRS80 +units=m +no_defs",
    "Germany" => "+proj=lcc +lat_1=49 +lat_2=53 +lat_0=51 +lon_0=10.5 +ellps=GRS80 +units=m +no_defs",
    "Greece" => "+proj=lcc +lat_1=36 +lat_2=39 +lat_0=37.5 +lon_0=23.5 +ellps=GRS80 +units=m +no_defs",
    "Hungary" => "+proj=lcc +lat_1=46 +lat_2=48.5 +lat_0=47.3 +lon_0=19 +ellps=GRS80 +units=m +no_defs",
    "Iceland" => "+proj=lcc +lat_1=63.5 +lat_2=66 +lat_0=64.5 +lon_0=-19 +ellps=GRS80 +units=m +no_defs",
    "Ireland" => "+proj=lcc +lat_1=52 +lat_2=54 +lat_0=53 +lon_0=-8 +ellps=GRS80 +units=m +no_defs",
    "Italy" => "+proj=lcc +lat_1=40 +lat_2=46 +lat_0=43 +lon_0=12 +ellps=GRS80 +units=m +no_defs",
    "Kosovo" => "+proj=lcc +lat_1=42 +lat_2=44 +lat_0=43 +lon_0=21 +ellps=GRS80 +units=m +no_defs",
    "Latvia" => "+proj=lcc +lat_1=56 +lat_2=58 +lat_0=57 +lon_0=25 +ellps=GRS80 +units=m +no_defs",
    "Liechtenstein" => "+proj=lcc +lat_1=46 +lat_2=47.5 +lat_0=47 +lon_0=9.5 +ellps=GRS80 +units=m +no_defs",
    "Lithuania" => "+proj=lcc +lat_1=54 +lat_2=56 +lat_0=55 +lon_0=24 +ellps=GRS80 +units=m +no_defs",
    "Luxembourg" => "+proj=lcc +lat_1=49 +lat_2=50 +lat_0=49.5 +lon_0=6 +ellps=GRS80 +units=m +no_defs",
    "Malta" => "+proj=lcc +lat_1=35.75 +lat_2=36 +lat_0=35.9 +lon_0=14.5 +ellps=GRS80 +units=m +no_defs",
    "Moldova" => "+proj=lcc +lat_1=46 +lat_2=48 +lat_0=47 +lon_0=28 +ellps=GRS80 +units=m +no_defs",
    "Monaco" => "+proj=lcc +lat_1=43 +lat_2=44 +lat_0=43.5 +lon_0=7.4 +ellps=GRS80 +units=m +no_defs",
    "Montenegro" => "+proj=lcc +lat_1=41.5 +lat_2=44.5 +lat_0=43 +lon_0=19.3 +ellps=GRS80 +units=m +no_defs",
    "Netherlands" => "+proj=lcc +lat_1=51 +lat_2=53 +lat_0=52 +lon_0=5.5 +ellps=GRS80 +units=m +no_defs",
    "Macedonia, The Former Yugoslav Republic Of" => "+proj=lcc +lat_1=40.5 +lat_2=42.5 +lat_0=41.5 +lon_0=21.5 +ellps=GRS80 +units=m +no_defs",
    "Norway" => "+proj=lcc +lat_1=58 +lat_2=71 +lat_0=64.5 +lon_0=11 +ellps=GRS80 +units=m +no_defs",
    "Poland" => "+proj=lcc +lat_1=49 +lat_2=54 +lat_0=51.5 +lon_0=19 +ellps=GRS80 +units=m +no_defs",
    "Portugal" => "+proj=lcc +lat_1=37 +lat_2=41 +lat_0=39 +lon_0=-8 +ellps=GRS80 +units=m +no_defs",
    "Romania" => "+proj=lcc +lat_1=44 +lat_2=47 +lat_0=45.5 +lon_0=25 +ellps=GRS80 +units=m +no_defs",
    "Russia" => "+proj=lcc +lat_1=50 +lat_2=60 +lat_0=55 +lon_0=37 +ellps=GRS80 +units=m +no_defs",  # western Russia
    "San Marino" => "+proj=lcc +lat_1=43 +lat_2=44.5 +lat_0=43.75 +lon_0=12.5 +ellps=GRS80 +units=m +no_defs",
    "Serbia" => "+proj=lcc +lat_1=43 +lat_2=45 +lat_0=44 +lon_0=20.5 +ellps=GRS80 +units=m +no_defs",
    "Slovakia" => "+proj=lcc +lat_1=48.5 +lat_2=49.5 +lat_0=48 +lon_0=19.5 +ellps=GRS80 +units=m +no_defs",
    "Slovenia" => "+proj=lcc +lat_1=45.5 +lat_2=47.5 +lat_0=46.5 +lon_0=15 +ellps=GRS80 +units=m +no_defs",
    "Spain" => "+proj=lcc +lat_1=36 +lat_2=44 +lat_0=40 +lon_0=-3 +ellps=GRS80 +units=m +no_defs",
    "Sweden" => "+proj=lcc +lat_1=56 +lat_2=68 +lat_0=62 +lon_0=15 +ellps=GRS80 +units=m +no_defs",
    "Switzerland" => "+proj=lcc +lat_1=46 +lat_2=48 +lat_0=47 +lon_0=8 +ellps=GRS80 +units=m +no_defs",
    "Turkey" => "+proj=lcc +lat_1=37 +lat_2=42 +lat_0=39.5 +lon_0=35 +ellps=GRS80 +units=m +no_defs",
    "Ukraine" => "+proj=lcc +lat_1=46 +lat_2=52 +lat_0=49 +lon_0=31 +ellps=GRS80 +units=m +no_defs",
    "United Kingdom" => "+proj=lcc +lat_1=49 +lat_2=61 +lat_0=55 +lon_0=-2 +ellps=airy +units=m +no_defs"
)



projection_info_map = Dict(
    # UTM ED50
    "ED_1950_UTM_Zone_30N" => "+proj=utm +zone=30 +ellps=intl +towgs84=-87,-98,-121 +units=m +no_defs",
    "ED_1950_UTM_Zone_31N" => "+proj=utm +zone=31 +ellps=intl +towgs84=-87,-98,-121 +units=m +no_defs",

    # # Lambert conformal conic variants
    # "LAMBERT CONFORMAL CONIC - Project Projection" => "+proj=lcc +lat_1=44 +lat_2=49 +lat_0=46.5 +lon_0=3 +datum=WGS84 +units=m +no_defs",
    # "LAMBERT CONFORMAL CONIC- GeoCapacity" => "+proj=lcc +lat_1=44 +lat_2=49 +lat_0=46.5 +lon_0=3 +datum=WGS84 +units=m +no_defs",
    # "LAMBERT CONFORMAL CONIC- EU GeoCapacity" => "+proj=lcc +lat_1=44 +lat_2=49 +lat_0=46.5 +lon_0=3 +datum=WGS84 +units=m +no_defs",
    # "Lambert conformal conic" => "+proj=lcc +lat_1=44 +lat_2=49 +lat_0=46.5 +lon_0=3 +datum=WGS84 +units=m +no_defs",

    # Hungarian EOV
    "EOV" => "EPSG:23700",
    
    # Irish Grid (TM65)
    "TM65 Irish Grid" => "+proj=tmerc +lat_0=53.5 +lon_0=-8 +k=1.000035 +x_0=200000 +y_0=250000 +ellps=mod_airy +units=m +no_defs",

    # WGS84 and variants
    "x: long - y: lat - WGS84" => "+proj=longlat +datum=WGS84 +no_defs",
    "WGS 84" => "+proj=longlat +datum=WGS84 +no_defs",
    "WGS84" => "+proj=longlat +datum=WGS84 +no_defs",
    "WGS-84" => "+proj=longlat +datum=WGS84 +no_defs",
    "GCS-WGS-84" => "+proj=longlat +datum=WGS84 +no_defs",
    "Decimal degrees" => "+proj=longlat +datum=WGS84 +no_defs",
    "Decimal Degrees" => "+proj=longlat +datum=WGS84 +no_defs",

    # ETRS89 / UTM
    "ETRS_1989_UTM_Zone_33N" => "+proj=utm +zone=33 +ellps=GRS80 +units=m +no_defs",
    "UTM35N" => "+proj=utm +zone=35 +datum=WGS84 +units=m +no_defs",

    # Belgium Lambert 72
    "Belgian datum 72, Lambert 1972" => "+proj=lcc +lat_0=90 +lon_0=4.367486666666666 +lat_1=49.8333339 +lat_2=51.16666723333333 +x_0=150000.013 +y_0=5400088.438 +ellps=intl +towgs84=106.868628,-52.297783,103.723893 +units=m +no_defs",

    # Czech S-JTSK / Krovak East-North
    "S-JTSK_Krovak_East_North" => "+proj=krovak +lat_0=49.5 +lon_0=24.8333333333333 +k=0.9999 +x_0=0 +y_0=0 +ellps=bessel +units=m +no_defs",

    # Macedonia TM
    "Macedonian Transverse Mercator" => "+proj=tmerc +lat_0=0 +lon_0=21 +k=0.9999 +x_0=7500000 +y_0=0 +ellps=GRS80 +units=m +no_defs",

    # Russia / Eastern Europe — Pulkovo 1942
    "Pulkovo 1942 - Zone 34" => "+proj=utm +zone=34 +ellps=krass +towgs84=24,-123,-94 +units=m +no_defs",
    " Pulkovo 1942 - Zone 34" => "+proj=utm +zone=34 +ellps=krass +towgs84=24,-123,-94 +units=m +no_defs",

    # Morocco
    "Nord_Maroc_Degree" => "+proj=longlat +datum=WGS84 +no_defs",

    # Slovenia — Gauss-Kruger
    "Slovenian Gauss Kruger" => "+proj=tmerc +lat_0=0 +lon_0=15 +k=0.9999 +x_0=500000 +y_0=0 +ellps=bessel +units=m +no_defs",
    "Gauss-Kruger coordinate system" => "+proj=tmerc +lat_0=0 +lon_0=15 +k=1 +x_0=500000 +y_0=0 +ellps=bessel +units=m +no_defs",

    # Fallback for missing
    "missing" => nothing
)

    longitudes = Float64[]
    latitudes = Float64[]

    r = 0

    for row in eachrow(df)
        # Get country and EPSG
        epsg_in = get(projection_info_map , row.Projection_Info, country_lcc_projection_map[row.COUNTRY])  # fallback to LAEA Europe if unknown
        r = r +1 
        print(r)
        trans = Proj4.Transformation(epsg_in, "EPSG:4326")
        
        # Transform the coordinate
        lonlat = trans([row.X, row.Y])
        push!(latitudes, lonlat[1])
        push!(longitudes, lonlat[2])
    end

    # Add new columns
    df.Lon = longitudes
    df.Lat = latitudes

return df

end 
