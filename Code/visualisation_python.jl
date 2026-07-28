using PyCall
using PlotlyJS 
using Kaleido
ENV["PYTHON"] = raw"C:\Users\VERBISTF\AppData\Local\Programs\Python\Python313\python.exe" # THis needs to change in HPC to ENV["PYTHON"] = "/usr/bin/python3"
#Pkg.build("PyCall")
# If package version not recoganised by PyCall, type: pip install "package name" 
# rerun Pkg.build("PyCall")
# py -m pip install numpy pandas geopandas seaborn plotly matplotlib contextily pyproj 
np = pyimport("numpy")
gpd = pyimport("geopandas")
pd = pyimport("pandas")
matplotlib =  pyimport("matplotlib")
plt = pyimport("matplotlib.pyplot")
mpl = pyimport("mpl_toolkits.axes_grid1")
make_axes_locatable = mpl.make_axes_locatable
ctx = pyimport("contextily")
shpgeo = pyimport("shapely.geometry")
Point = shpgeo.Point
pyproj = pyimport("pyproj")
Proj = pyproj.Proj
transform = pyproj.transform
matplotlib_lines = pyimport("matplotlib.lines")
Line2D = matplotlib_lines.Line2D
matplotlib_patches = pyimport("matplotlib.patches")
FancyArrowPatch = matplotlib_patches.FancyArrowPatch
plt_ax = pyimport("matplotlib.axes")
add_patch = plt_ax.Axes.add_patch
matplotlib_collections = pyimport("matplotlib.collections")
LineCollection = matplotlib_collections.LineCollection
sankey = pyimport("pySankey.sankey")
sankey = sankey.sankey
go = pyimport("plotly.graph_objects")
plotlyio = pyimport("plotly.io")
# latex font
# matplotlib.rcParams["text.usetex"] = false
# matplotlib.rcParams["font.family"] = "serif"
# matplotlib.rcParams["font.serif"] = ["Computer Modern"]
# plt.switch_backend("TkAgg")


# Enable LaTeX rendering
rc = pyimport("matplotlib").rc 
rc("text", usetex=true)
rc("font", family="serif")


# shapefile_eu = raw"C:\Users\VERBISTF\OneDrive - KU Leuven\PhD Flore\P3_CCUS_network\3C_case_study\Input data files\Visuals\NUTS_RG_01M_2024_3035.shp\NUTS_RG_01M_2024_3035.shp"
function sankey_scenario_change_py(results_industry_file, Scenario_name_1::String, Scenario_name_2::String, Figure_name::String)
  

    Industry_connection_results_1 =  DataFrame(XLSX.readtable(results_industry_file,  "$(Scenario_name_1)_$(CO2_tax)_$(Subcase_name)"))
    Industry_connection_results_2 =  DataFrame(XLSX.readtable(results_industry_file,  "$(Scenario_name_2)_$(CO2_tax)_$(Subcase_name)"))
    DF_sankey = DataFrame(
        Emitter_id = EMITTERS,
        Scenario_1 = fill("", length(EMITTERS)),
        Route_sn_1 = fill("", length(EMITTERS)),
        Scenario_2 = fill("", length(EMITTERS)), 
        Route_sn_2 = fill("", length(EMITTERS))
    )
    Emitters_1 = import_data_industry(industry_data_file::Any, Scenario_name_1::String, Scenario_horizon::Int64) #, (load_data=true; load_data))
    Emitters_2 = import_data_industry(industry_data_file::Any, Scenario_name_2::String, Scenario_horizon::Int64) #, (load_data=true; load_data))
    Emitter_extract_1 = Emitters_1[in.(Emitters_1[!, :Emitter_id], Ref(EMITTERS)), :]
    Emitter_extract_2 = Emitters_2[in.(Emitters_2[!, :Emitter_id], Ref(EMITTERS)), :]

    cc_emitter_1 = Dict(Industry_connection_results_1[e, "Emitters"] => Industry_connection_results_1[e, "Bin_connection"] for e in 1:1:length(Industry_connection_results_1[:,"Bin_connection"]))
    cc_emitter_2 = Dict(Industry_connection_results_2[e, "Emitters"] => Industry_connection_results_2[e, "Bin_connection"] for e in 1:1:length(Industry_connection_results_2[:,"Bin_connection"]))

    for e in EMITTERS 
        try 
            if cc_emitter_1[e] .>= 0.5 # most optimal route of scenario 1 contains corbon capture 
                DF_sankey[DF_sankey[:, "Emitter_id"] .== e, "Route_sn_1"] = Emitters_1[Emitters_1[:, "Emitter_id"] .== e, "Route_name_1"]
                if Emitter_extract_1[Emitter_extract_1[:,"Emitter_id"] .== e,"Capture_ofwhich_bio_1_tCO2ptpa"][1] > 0 
                    DF_sankey[DF_sankey[:, "Emitter_id"] .== e, "Scenario_1"] .=  "Bio + CCS"
                else 
                    DF_sankey[DF_sankey[:, "Emitter_id"] .== e, "Scenario_1"] .=  "Fossil + CCS"
                end
            else  # optimal route of scenario 1 does not contain carbon capture 
                DF_sankey[DF_sankey[:, "Emitter_id"] .== e, "Route_sn_1"] = Emitters_1[Emitters_1[:, "Emitter_id"] .== e, "Route_name_noCC"]

                if any(occursin.(["BM", "BMW"], DF_sankey[DF_sankey[!, :Emitter_id] .== e, :Route_sn_1][1]))
                    DF_sankey[DF_sankey[:, "Emitter_id"] .== e, "Scenario_1"] .= "Bio"
                elseif any(occursin.(["NG", "(LN)", "REF-SMR"], DF_sankey[DF_sankey[!, :Emitter_id] .== e, :Route_sn_1][1]))
                    DF_sankey[DF_sankey[:, "Emitter_id"] .== e, "Scenario_1"] .= "Fossil"
                elseif any(occursin.(["(EL)", "EAF"], DF_sankey[DF_sankey[!, :Emitter_id] .== e, :Route_sn_1][1])) 
                    DF_sankey[DF_sankey[:, "Emitter_id"] .== e, "Scenario_1"] .= "Electric"
                else
                    DF_sankey[DF_sankey[:, "Emitter_id"] .== e, "Scenario_1"] .= "Other"
                end
            end
        catch # emitters are not included 
            DF_sankey[DF_sankey[:, "Emitter_id"] .== e, "Scenario_1"] .= "Exit"
            DF_sankey[DF_sankey[:, "Emitter_id"] .== e, "Route_sn_1"] .= "missing"
        end
        try 
            if cc_emitter_2[e] .>= 0.5 # most optimal route of scenario 2 contains corbon capture 
                DF_sankey[DF_sankey[:, "Emitter_id"] .== e, "Route_sn_2"] = Emitters_2[Emitters_2[:, "Emitter_id"] .== e, "Route_name_1"]

                if Emitter_extract_2[Emitter_extract_2[:,"Emitter_id"] .== e,"Capture_ofwhich_bio_1_tCO2ptpa"][1] > 0 
                    DF_sankey[DF_sankey[:, "Emitter_id"] .== e, "Scenario_2"] .=  "Bio + CCS"
                else
                    DF_sankey[DF_sankey[:, "Emitter_id"] .== e, "Scenario_2"] .=  "Fossil + CCS"
                end
            else   # optimal route of scenario 2 does not contain carbon capture 
                DF_sankey[DF_sankey[:, "Emitter_id"] .== e, "Route_sn_2"] = Emitters_2[Emitters_2[:, "Emitter_id"] .== e, "Route_name_noCC"]

                if any(occursin.(["BM", "BMW"], DF_sankey[DF_sankey[!, :Emitter_id] .== e, :Route_sn_2][1]))
                    DF_sankey[DF_sankey[:, "Emitter_id"] .== e, "Scenario_2"] .= "Bio"
                elseif any(occursin.(["NG", "(LN)", "REF-SMR"], DF_sankey[DF_sankey[!, :Emitter_id] .== e, :Route_sn_2][1])) 
                    DF_sankey[DF_sankey[:, "Emitter_id"] .== e, "Scenario_2"] .= "Fossil"
                elseif any(occursin.(["(EL)", "EAF"], DF_sankey[DF_sankey[!, :Emitter_id] .== e, :Route_sn_2][1])) 
                    DF_sankey[DF_sankey[:, "Emitter_id"] .== e, "Scenario_2"] .= "Electric"
                else
                    DF_sankey[DF_sankey[:, "Emitter_id"] .== e, "Scenario_2"] .= "Other"
                end
                
            end
        catch # emitters are not included 
            DF_sankey[DF_sankey[:, "Emitter_id"] .== e, "Scenario_2"] .= "Exit"
            DF_sankey[DF_sankey[:, "Emitter_id"] .== e, "Route_sn_2"] .= "missing"

        end

    end
    left_weights = combine(DataFrames.groupby(DF_sankey, :Scenario_1), nrow => :left_weight)
    right_weights = combine(DataFrames.groupby(DF_sankey, :Scenario_2), nrow => :right_weight)
    DF_sankey = leftjoin(DF_sankey, left_weights, on=:Scenario_1)
    DF_sankey = leftjoin(DF_sankey, right_weights, on=:Scenario_2)
    
  
    ax1 = plt.axes()
    colors = Dict("Other" => "black", "Bio" => "lightgreen", "Fossil + CCS" => "grey", "Bio + CCS" => "darkgreen", "Fossil" => "brown", "Electric" => "steelblue", "Exit" => "black")
    ax1 = sankey(DF_sankey[!,"Scenario_1"], DF_sankey[!,"Scenario_2"],  colorDict=colors, aspect=10, fontsize=12) #    leftWeight=DF_sankey[!, "left_weight"], rightWeight=DF_sankey[!, "right_weight"], 
    plt.annotate("No CDR credits", xy = (-1.7, length(EMITTERS) + 20), fontsize = 12,  fontweight="bold")
    plt.annotate("CDR credits", xy = (20, length(EMITTERS) + 20), fontsize = 12, fontweight="bold")
    plt.tight_layout()
    plt.gcf().set_size_inches((10, 10))

    save_path = "./Figures/$(Figure_name).svg"
    plt.savefig(save_path, bbox_inches="tight")
    plt.show()
    return DF_sankey 
end

function sankey_3_scenario_change_py(Scenario_name_1::String, Scenario_name_2::String, Scenario_name_3::String, Plotting::Bool)

    file_industry_1 = "./Output data files/CSV intermediaries $(detail_level)/Results_industry$(Scenario_name_1)_$(CO2_tax)_$(Subcase_name).csv"
    file_industry_2 = "./Output data files/CSV intermediaries $(detail_level)/Results_industry$(Scenario_name_2)_$(CO2_tax)_$(Subcase_name).csv"
    file_industry_3 = "./Output data files/CSV intermediaries $(detail_level)/Results_industry$(Scenario_name_3)_$(CO2_tax)_$(Subcase_name).csv"

    Industry_connection_results_1 = CSV.read(file_industry_1, DataFrame)
    Industry_connection_results_2 = CSV.read(file_industry_2, DataFrame)   
    Industry_connection_results_3 = CSV.read(file_industry_3, DataFrame)

    Annotation_1 = "No CDR price"
    Annotation_2 = "CDR price"
    Annotation_3 = "Exit"

    DF_sankey = DataFrame(
        Emitter_id = EMITTERS,
        Product_route_name =  fill("", length(EMITTERS)),
        Scenario_1 =    fill("", length(EMITTERS)),
        Route_sn_1 =    fill("", length(EMITTERS)),
        Scenario_2 =    fill("", length(EMITTERS)), 
        Route_sn_2 =    fill("", length(EMITTERS)), 
        Scenario_3 =    fill("", length(EMITTERS)), 
        Route_sn_3 =    fill("", length(EMITTERS)), 

    )
    Emitters_1 = import_data_industry(CO2_tax::Any, Scenario_name_1::String, Scenario_horizon::Int64) #, (load_data=true; load_data))
    Emitters_2 = import_data_industry(CO2_tax::Any, Scenario_name_2::String, Scenario_horizon::Int64) #, (load_data=true; load_data))
    Emitters_3 = import_data_industry(CO2_tax::Any, Scenario_name_3::String, Scenario_horizon::Int64) #, (load_data=true; load_data))

    Emitter_extract_1 = Emitters_1[in.(Emitters_1[!, :Emitter_id], Ref(EMITTERS)), :]
    Emitter_extract_2 = Emitters_2[in.(Emitters_2[!, :Emitter_id], Ref(EMITTERS)), :]
    Emitter_extract_3 = Emitters_3[in.(Emitters_3[!, :Emitter_id], Ref(EMITTERS)), :]

    cc_emitter_1 = Dict(Industry_connection_results_1[e, "Emitters"] => Industry_connection_results_1[e, "Bin_connection"] for e in 1:1:length(Industry_connection_results_1[:,"Bin_connection"]))
    cc_emitter_2 = Dict(Industry_connection_results_2[e, "Emitters"] => Industry_connection_results_2[e, "Bin_connection"] for e in 1:1:length(Industry_connection_results_2[:,"Bin_connection"]))
    cc_emitter_3 = Dict(Industry_connection_results_3[e, "Emitters"] => Industry_connection_results_3[e, "Bin_connection"] for e in 1:1:length(Industry_connection_results_3[:,"Bin_connection"]))

    for e in EMITTERS 
        DF_sankey[DF_sankey[:, "Emitter_id"] .== e, "Product_route_name"] = Emitters_1[Emitters_1[:, "Emitter_id"] .== e, "Product_route_name"]
        try 
            if cc_emitter_1[e] .>= 0.5 # most optimal route of scenario 1 contains corbon capture 
                DF_sankey[DF_sankey[:, "Emitter_id"] .== e, "Route_sn_1"] = Emitters_1[Emitters_1[:, "Emitter_id"] .== e, "Route_name_1"]
                if Emitter_extract_1[Emitter_extract_1[:,"Emitter_id"] .== e,"Capture_ofwhich_bio_1_tCO2ptpa"][1] > 0 
                    DF_sankey[DF_sankey[:, "Emitter_id"] .== e, "Scenario_1"] .=  "Bio + CCS"
                else 
                    DF_sankey[DF_sankey[:, "Emitter_id"] .== e, "Scenario_1"] .=  "Fossil + CCS"
                end
            else  # optimal route of scenario 1 does not contain carbon capture 
                DF_sankey[DF_sankey[:, "Emitter_id"] .== e, "Route_sn_1"] = Emitters_1[Emitters_1[:, "Emitter_id"] .== e, "Route_name_noCC"]

                if any(occursin.(["BM", "BMW"], DF_sankey[DF_sankey[!, :Emitter_id] .== e, :Route_sn_1][1]))
                    DF_sankey[DF_sankey[:, "Emitter_id"] .== e, "Scenario_1"] .= "Bio"
                elseif any(occursin.(["NG", "(LN)", "REF-SMR"], DF_sankey[DF_sankey[!, :Emitter_id] .== e, :Route_sn_1][1]))
                    DF_sankey[DF_sankey[:, "Emitter_id"] .== e, "Scenario_1"] .= "Fossil"
                elseif any(occursin.(["(EL)", "EAF"], DF_sankey[DF_sankey[!, :Emitter_id] .== e, :Route_sn_1][1])) 
                    DF_sankey[DF_sankey[:, "Emitter_id"] .== e, "Scenario_1"] .= "Electric"
                else
                    DF_sankey[DF_sankey[:, "Emitter_id"] .== e, "Scenario_1"] .= "Other"
                end
            end
        catch # emitters are not included 
            DF_sankey[DF_sankey[:, "Emitter_id"] .== e, "Scenario_1"] .= "Exit"
            DF_sankey[DF_sankey[:, "Emitter_id"] .== e, "Route_sn_1"] .= "missing"
        end
        try 
            if cc_emitter_2[e] .>= 0.5 # most optimal route of scenario 2 contains carbon capture 
                DF_sankey[DF_sankey[:, "Emitter_id"] .== e, "Route_sn_2"] = Emitters_2[Emitters_2[:, "Emitter_id"] .== e, "Route_name_1"]

                if Emitter_extract_2[Emitter_extract_2[:,"Emitter_id"] .== e,"Capture_ofwhich_bio_1_tCO2ptpa"][1] > 0 
                    DF_sankey[DF_sankey[:, "Emitter_id"] .== e, "Scenario_2"] .=  "Bio + CCS"
                else
                    DF_sankey[DF_sankey[:, "Emitter_id"] .== e, "Scenario_2"] .=  "Fossil + CCS"
                end
            else   # optimal route of scenario 2 does not contain carbon capture 
                DF_sankey[DF_sankey[:, "Emitter_id"] .== e, "Route_sn_2"] = Emitters_2[Emitters_2[:, "Emitter_id"] .== e, "Route_name_noCC"]

                if any(occursin.(["BM", "BMW"], DF_sankey[DF_sankey[!, :Emitter_id] .== e, :Route_sn_2][1]))
                    DF_sankey[DF_sankey[:, "Emitter_id"] .== e, "Scenario_2"] .= "Bio"
                elseif any(occursin.(["NG", "(LN)", "REF-SMR"], DF_sankey[DF_sankey[!, :Emitter_id] .== e, :Route_sn_2][1])) 
                    DF_sankey[DF_sankey[:, "Emitter_id"] .== e, "Scenario_2"] .= "Fossil"
                elseif any(occursin.(["(EL)", "EAF"], DF_sankey[DF_sankey[!, :Emitter_id] .== e, :Route_sn_2][1])) 
                    DF_sankey[DF_sankey[:, "Emitter_id"] .== e, "Scenario_2"] .= "Electric"
                else
                    DF_sankey[DF_sankey[:, "Emitter_id"] .== e, "Scenario_2"] .= "Other"
                end
                
            end
        catch # emitters are not included 
            DF_sankey[DF_sankey[:, "Emitter_id"] .== e, "Scenario_2"] .= "Exit"
            DF_sankey[DF_sankey[:, "Emitter_id"] .== e, "Route_sn_2"] .= "missing"

        end
        try 
            if cc_emitter_3[e] .>= 0.5 # most optimal route of scenario 3 contains corbon capture 
                DF_sankey[DF_sankey[:, "Emitter_id"] .== e, "Route_sn_3"] = Emitters_3[Emitters_3[:, "Emitter_id"] .== e, "Route_name_1"]

                if Emitter_extract_3[Emitter_extract_3[:,"Emitter_id"] .== e,"Capture_ofwhich_bio_1_tCO2ptpa"][1] > 0 
                    DF_sankey[DF_sankey[:, "Emitter_id"] .== e, "Scenario_3"] .=  "Bio + CCS"
                else
                    DF_sankey[DF_sankey[:, "Emitter_id"] .== e, "Scenario_3"] .=  "Fossil + CCS"
                end
            else   # optimal route of scenario 2 does not contain carbon capture 
                DF_sankey[DF_sankey[:, "Emitter_id"] .== e, "Route_sn_3"] = Emitters_3[Emitters_3[:, "Emitter_id"] .== e, "Route_name_noCC"]

                if any(occursin.(["BM", "BMW"], DF_sankey[DF_sankey[!, :Emitter_id] .== e, :Route_sn_3][1]))
                    DF_sankey[DF_sankey[:, "Emitter_id"] .== e, "Scenario_3"] .= "Bio"
                elseif any(occursin.(["NG", "(LN)", "REF-SMR"], DF_sankey[DF_sankey[!, :Emitter_id] .== e, :Route_sn_3][1])) 
                    DF_sankey[DF_sankey[:, "Emitter_id"] .== e, "Scenario_3"] .= "Fossil"
                elseif any(occursin.(["(EL)", "EAF"], DF_sankey[DF_sankey[!, :Emitter_id] .== e, :Route_sn_3][1])) 
                    DF_sankey[DF_sankey[:, "Emitter_id"] .== e, "Scenario_3"] .= "Electric"
                else
                    DF_sankey[DF_sankey[:, "Emitter_id"] .== e, "Scenario_3"] .= "Other"
                end
                
            end
        catch # emitters are not included 
            DF_sankey[DF_sankey[:, "Emitter_id"] .== e, "Scenario_3"] .= "Exit"
            DF_sankey[DF_sankey[:, "Emitter_id"] .== e, "Route_sn_3"] .= "missing"

        end


    end

    # Step 1: Define labels and dimensions
    Labels = ["Fossil", "Fossil + CCS", "Bio", "Bio + CCS", "Electric", "Other", "Exit"]
    n_labels = length(Labels)

    # All labels for 3 scenarios
    Labels_3 = vcat(Labels, Labels, Labels)

    # Step 2: Map each (label, scenario) to its node index (starting at 1)
    label_to_index = Dict{Tuple{String, Int}, Int}()
    for (i, label) in enumerate(Labels)
        label_to_index[(label, 1)] = i                      # Scenario 1 → 1–7
        label_to_index[(label, 2)] = i + n_labels           # Scenario 2 → 8–14
        label_to_index[(label, 3)] = i + 2n_labels          # Scenario 3 → 15–21
    end

    # Step 3: Count transitions between scenarios using your DF_sankey
    flows = Dict{Tuple{Int, Int}, Int}()

    for row in eachrow(DF_sankey)
        # Scenario 1 → 2
        s1 = label_to_index[(row.Scenario_1, 1)]
        s2 = label_to_index[(row.Scenario_2, 2)]
        flows[(s1, s2)] = get(flows, (s1, s2), 0) + 1

        # Scenario 2 → 3
        s2b = label_to_index[(row.Scenario_2, 2)]
        s3 = label_to_index[(row.Scenario_3, 3)]
        flows[(s2b, s3)] = get(flows, (s2b, s3), 0) + 1
    end

    # Step 4: Prepare Sankey inputs
    Sources = Int[]
    Targets = Int[]
    Values = Int[]

    for ((s, t), v) in flows
        push!(Sources, s)
        push!(Targets, t)
        push!(Values, v)
    end

    # Step 5: Positioning
    Pos_x = vcat(
        fill(0.0, n_labels),
        fill(0.33, n_labels),
        fill(0.66, n_labels)
    )    
    Pos_y = repeat([0.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6], 3)


    # Step 6: Color setup
    base_colors = ["sienna", "grey", "lightgreen", "darkgreen", "steelblue", "black", "black"]
    node_colors = vcat(base_colors, base_colors, base_colors)
    link_colors = [node_colors[s] for s in Sources]  # s is now 1-based
    opacity = 0.4 
    link_colors_rgba = [
        begin
            hex = node_colors[src]  # Get the source node color
            c = parse(Colorant, hex)
            r, g, b = round.(Int, (red(c), green(c), blue(c)) .* 255)
            "rgba($r,$g,$b,$opacity)"
        end
        for src in Sources
        ]

    # Step 2: Scenario name annotations using Dict()
    annotations = [
        Dict(
            :x => 0.0,  # x position for Scenario 1
            :y => 1.1,  # y position slightly above the nodes
            :text => "$(Annotation_1)",  # Text for the annotation
            :showarrow => false,
            :font => Dict(:size => 16, :color => "black"),
            :align => "center"
        ),
        Dict(
            :x => 0.5, # x position for Scenario 2
            :y => 1.1,  # y position slightly above the nodes
            :text => "$(Annotation_2)",
            :showarrow => false,
            :font => Dict(:size => 16, :color => "black"),
            :align => "center"
        ),
        Dict(
            :x => 1.0,  # x position for Scenario 3
            :y => 1.1,  # y position slightly above the nodes
            :text => "$(Annotation_3)",
            :showarrow => false,
            :font => Dict(:size => 16, :color => "black"),
            :align => "center"
        )
    ]

    # Step 7: Plot it!

    if Plotting == true
        fig = go.Figure(go.Sankey(
                arrangement="fixed",
                node=Dict(
                    :label=>Labels_3,
                    :x=>Pos_x,
                    #:y=>Pos_y,
                    :color=>node_colors,
                    :pad=>5,
                    :thickness=>20
                ),
                link=Dict(
                    :source=>Sources .- 1,  # Plotly expects 0-based!
                    :target=>Targets .- 1,
                    :value=>Values,
                    :color=>link_colors_rgba)),
            layout=Dict(
                :annotations=>annotations  # Add the scenario name annotation
            )
        )

    # save_path = "./Figures/$(Figure_name).png"
    # savefig(fig,save_path)
        fig.show()
    else 
        skip 
    end
    # plotlyio.write_image(fig, "test.png")
    return  DF_sankey
end


function sankey_2_scenario_change_py(Scenario_name_1::String, Scenario_name_2::String, Plotting::Bool)
    

    if MPEC .== true 
        file_industry_1 = "./Output data files/CSV intermediaries $(detail_level)/MPEC/Results_industry_$(Scenario_name_1)_$(CO2_tax)_$(Subcase_name).csv"
        file_industry_2 = "./Output data files/CSV intermediaries $(detail_level)/MPEC/Results_industry_$(Scenario_name_2)_$(CO2_tax)_$(Subcase_name).csv"
    else   
      file_industry_1 = "./Output data files/CSV intermediaries $(detail_level)/Results_industry_$(Scenario_name_1)_$(CO2_tax)_$(Subcase_name).csv"
        file_industry_2 = "./Output data files/CSV intermediaries $(detail_level)/Results_industry_$(Scenario_name_2)_$(CO2_tax)_$(Subcase_name).csv"
    end
    #


    Industry_connection_results_1 = CSV.read(file_industry_1, DataFrame)
    Industry_connection_results_2 = CSV.read(file_industry_2, DataFrame)   

    if Scenario_name_1 == "No_CDR_price"
        Annotation_1 = "EU based - no CDR"
        Annotation_2 = "EU based - CDR"
    elseif Scenario_name_2 == "Exit"
        Annotation_1 = "EU based - CDR"
        Annotation_2 = "EU exit - CDR"
    else
        Annotation_1 = "error"
        Annotation_2 = "error"
    end

    DF_sankey = DataFrame(
        Emitter_id = EMITTERS,
        Product_route_name =  fill("", length(EMITTERS)),
        Scenario_1 =    fill("", length(EMITTERS)),
        Route_sn_1 =    fill("", length(EMITTERS)),
        Scenario_2 =    fill("", length(EMITTERS)), 
        Route_sn_2 =    fill("", length(EMITTERS))
    )
    Emitters_1 = import_data_industry(CO2_tax::Any, Scenario_name_1::String, Scenario_horizon::Int64) #, (load_data=true; load_data))
    Emitters_2 = import_data_industry(CO2_tax::Any, Scenario_name_2::String, Scenario_horizon::Int64) #, (load_data=true; load_data))

    Emitter_extract_1 = Emitters_1[in.(Emitters_1[!, :Emitter_id], Ref(EMITTERS)), :]
    Emitter_extract_2 = Emitters_2[in.(Emitters_2[!, :Emitter_id], Ref(EMITTERS)), :]

    cc_emitter_1 = Dict(Industry_connection_results_1[e, "Emitters"] => Industry_connection_results_1[e, "Bin_connection"] for e in 1:1:length(Industry_connection_results_1[:,"Bin_connection"]))
    cc_emitter_2 = Dict(Industry_connection_results_2[e, "Emitters"] => Industry_connection_results_2[e, "Bin_connection"] for e in 1:1:length(Industry_connection_results_2[:,"Bin_connection"]))

    for e in EMITTERS 
        DF_sankey[DF_sankey[:, "Emitter_id"] .== e, "Product_route_name"] = Emitters_1[Emitters_1[:, "Emitter_id"] .== e, "Product_route_name"]
        try 
            if cc_emitter_1[e] .>= 0.5 # most optimal route of scenario 1 contains corbon capture 
                DF_sankey[DF_sankey[:, "Emitter_id"] .== e, "Route_sn_1"] = Emitters_1[Emitters_1[:, "Emitter_id"] .== e, "Route_name_1"]
                if Emitter_extract_1[Emitter_extract_1[:,"Emitter_id"] .== e,"Capture_ofwhich_bio_1_tCO2ptpa"][1] > 0 
                    DF_sankey[DF_sankey[:, "Emitter_id"] .== e, "Scenario_1"] .=  "Bio + CCS"
                else 
                    DF_sankey[DF_sankey[:, "Emitter_id"] .== e, "Scenario_1"] .=  "Fossil + CCS"
                end
            else  # optimal route of scenario 1 does not contain carbon capture 
                DF_sankey[DF_sankey[:, "Emitter_id"] .== e, "Route_sn_1"] = Emitters_1[Emitters_1[:, "Emitter_id"] .== e, "Route_name_noCC"]

                if any(occursin.(["BM", "BMW"], DF_sankey[DF_sankey[!, :Emitter_id] .== e, :Route_sn_1][1]))
                    DF_sankey[DF_sankey[:, "Emitter_id"] .== e, "Scenario_1"] .= "Bio"
                elseif any(occursin.(["NG", "(LN)", "REF-SMR"], DF_sankey[DF_sankey[!, :Emitter_id] .== e, :Route_sn_1][1]))
                    DF_sankey[DF_sankey[:, "Emitter_id"] .== e, "Scenario_1"] .= "Fossil"
                elseif any(occursin.(["(EL)", "EAF"], DF_sankey[DF_sankey[!, :Emitter_id] .== e, :Route_sn_1][1])) 
                    DF_sankey[DF_sankey[:, "Emitter_id"] .== e, "Scenario_1"] .= "Electric"
                else
                    DF_sankey[DF_sankey[:, "Emitter_id"] .== e, "Scenario_1"] .= "Other"
                end
            end
        catch # emitters are not included 
            DF_sankey[DF_sankey[:, "Emitter_id"] .== e, "Scenario_1"] .= "Exit"
            DF_sankey[DF_sankey[:, "Emitter_id"] .== e, "Route_sn_1"] .= "missing"
        end
        try 
            if cc_emitter_2[e] .>= 0.5 # most optimal route of scenario 2 contains carbon capture 
                DF_sankey[DF_sankey[:, "Emitter_id"] .== e, "Route_sn_2"] = Emitters_2[Emitters_2[:, "Emitter_id"] .== e, "Route_name_1"]

                if Emitter_extract_2[Emitter_extract_2[:,"Emitter_id"] .== e,"Capture_ofwhich_bio_1_tCO2ptpa"][1] > 0 
                    DF_sankey[DF_sankey[:, "Emitter_id"] .== e, "Scenario_2"] .=  "Bio + CCS"
                else
                    DF_sankey[DF_sankey[:, "Emitter_id"] .== e, "Scenario_2"] .=  "Fossil + CCS"
                end
            else   # optimal route of scenario 2 does not contain carbon capture 
                DF_sankey[DF_sankey[:, "Emitter_id"] .== e, "Route_sn_2"] = Emitters_2[Emitters_2[:, "Emitter_id"] .== e, "Route_name_noCC"]

                if any(occursin.(["BM", "BMW"], DF_sankey[DF_sankey[!, :Emitter_id] .== e, :Route_sn_2][1]))
                    DF_sankey[DF_sankey[:, "Emitter_id"] .== e, "Scenario_2"] .= "Bio"
                elseif any(occursin.(["NG", "(LN)", "REF-SMR"], DF_sankey[DF_sankey[!, :Emitter_id] .== e, :Route_sn_2][1])) 
                    DF_sankey[DF_sankey[:, "Emitter_id"] .== e, "Scenario_2"] .= "Fossil"
                elseif any(occursin.(["(EL)", "EAF"], DF_sankey[DF_sankey[!, :Emitter_id] .== e, :Route_sn_2][1])) 
                    DF_sankey[DF_sankey[:, "Emitter_id"] .== e, "Scenario_2"] .= "Electric"
                else
                    DF_sankey[DF_sankey[:, "Emitter_id"] .== e, "Scenario_2"] .= "Other"
                end
                
            end
        catch # emitters are not included 
            DF_sankey[DF_sankey[:, "Emitter_id"] .== e, "Scenario_2"] .= "Exit"
            DF_sankey[DF_sankey[:, "Emitter_id"] .== e, "Route_sn_2"] .= "missing"

        end
    
    end
   
    if Plotting == true
        if Scenario_name_1 .== "No_CDR_price"

                    # Step 1: Define labels and dimensions
            Labels = ["Fossil", "Fossil + CCS", "Bio", "Bio + CCS", "Electric", "Other", "Exit"]
            n_labels = length(Labels)

            # All labels for 3 scenarios
            Labels_3 = vcat(Labels, Labels)

            # Step 2: Map each (label, scenario) to its node index (starting at 1)
            label_to_index = Dict{Tuple{String, Int}, Int}()
            for (i, label) in enumerate(Labels)
                label_to_index[(label, 1)] = i                      # Scenario 1 → 1–7
                label_to_index[(label, 2)] = i + n_labels           # Scenario 2 → 8–14
                label_to_index[(label, 3)] = i + 2n_labels          # Scenario 3 → 15–21
            end

            # Step 3: Count transitions between scenarios using your DF_sankey
            flows = Dict{Tuple{Int, Int}, Int}()

            for row in eachrow(DF_sankey)
                # Scenario 1 → 2
                s1 = label_to_index[(row.Scenario_1, 1)]
                s2 = label_to_index[(row.Scenario_2, 2)]
                flows[(s1, s2)] = get(flows, (s1, s2), 0) + 1

                # # Scenario 2 → 3
                # s2b = label_to_index[(row.Scenario_2, 2)]
                # s3 = label_to_index[(row.Scenario_3, 3)]
                # flows[(s2b, s3)] = get(flows, (s2b, s3), 0) + 1
            end

            # Step 4: Prepare Sankey inputs
            Sources = Int[]
            Targets = Int[]
            Values = Int[]

            for ((s, t), v) in flows
                push!(Sources, s)
                push!(Targets, t)
                push!(Values, v)
            end

            # Step 5: Positioning
            Pos_x = vcat(
                fill(0.0, n_labels),
                fill(0.5, n_labels)
            )    

            base_colors = ["sienna", "grey", "lightgreen", "darkgreen", "steelblue", "black", "black"]
            node_colors = vcat(base_colors, base_colors)
            link_colors = [node_colors[s] for s in Sources]  # s is now 1-based
            opacity = 0.4 
            link_colors_rgba = [
                begin
                    hex = node_colors[src]  # Get the source node color
                    c = parse(Colorant, hex)
                    r, g, b = round.(Int, (red(c), green(c), blue(c)) .* 255)
                    "rgba($r,$g,$b,$opacity)"
                end
                for src in Sources
                ]

            # Step 2: Scenario name annotations using Dict()
            annotations = [
                Dict(
                    :x => 0.0,  # x position for Scenario 1
                    :y => 1.08,  # y position slightly above the nodes
                    :text => "$(Annotation_1)",  # Text for the annotation
                    :showarrow => false,
                    :font => Dict(:size => 20, :color => "black"),
                    :align => "center"
                ),
                Dict(
                    :x => 1.0, # x position for Scenario 2
                    :y => 1.08,  # y position slightly above the nodes
                    :text => "$(Annotation_2)",
                    :showarrow => false,
                    :font => Dict(:size => 20, :color => "black"),
                    :align => "center"
                )
            ]
              flow_annotations = []

                # for i in eachindex(Sources)

                #     push!(flow_annotations,
                #         Dict(
                #             :x => 0.25,   # halfway between columns
                #             :y => 1 - (i / (length(Sources)+1)),   # spread vertically
                #             :text => string(Values[i]),
                #             :showarrow => false,
                #             :font => Dict(
                #                 :size => 12,
                #                 :color => "black"
                #             ),
                #             :bgcolor => "white",
                #             :bordercolor => "black",
                #             :borderwidth => 1
                #         )
                #     )
                # end


            # Step 7: Plot it!


            Labels_3 = vcat(Labels, Labels)
            fig = go.Figure(go.Sankey(
                    arrangement="snap",
                    node=Dict(
                        :label=>Labels_3,
                        :x=>Pos_x,
                        #:y=>Pos_y,
                        :color=>node_colors,
                        :pad=>5,
                        :thickness=>20,
                    ),
                    link=Dict(
                        :source=>Sources .- 1,  # Plotly expects 0-based!
                        :target=>Targets .- 1,
                        :value=>Values,
                        :color=>link_colors_rgba)),
                layout=Dict(
                    :annotations=>vcat(annotations, flow_annotations)  # Add the scenario name annotation
                ))
  


        else

            # Step 1: Define labels and dimensions
            Labels = ["Fossil", "Fossil + CCS", "Bio + CCS", "Bio",  "Electric", "Exit", "Other"]
            n_labels = length(Labels)

            # All labels for 3 scenarios
            Labels_3 = vcat(Labels, Labels)

            # Step 2: Map each (label, scenario) to its node index (starting at 1)
            label_to_index = Dict{Tuple{String, Int}, Int}()
            for (i, label) in enumerate(Labels)
                label_to_index[(label, 1)] = i                      # Scenario 1 → 1–7
                label_to_index[(label, 2)] = i + n_labels           # Scenario 2 → 8–14
            end

            # Step 3: Count transitions between scenarios using your DF_sankey
            flows = Dict{Tuple{Int, Int}, Int}()

            for row in eachrow(DF_sankey)
                # Scenario 1 → 2
                s1 = label_to_index[(row.Scenario_1, 1)]
                s2 = label_to_index[(row.Scenario_2, 2)]
                flows[(s1, s2)] = get(flows, (s1, s2), 0) + 1
            end

            # Step 4: Prepare Sankey inputs
            Sources = Int[]
            Targets = Int[]
            Values = Int[]

            for ((s, t), v) in flows
                push!(Sources, s)
                push!(Targets, t)
                push!(Values, v)
            end

            # Step 5: Positioning
            Pos_x = vcat(
                fill(0.0, n_labels),
                fill(0.5, n_labels)
            )    

            base_colors = ["sienna", "grey", "darkgreen", "lightgreen", "steelblue", "black", "black"]
            node_colors = vcat(base_colors, base_colors)
            link_colors = [node_colors[s] for s in Sources]  # s is now 1-based
            opacity = 0.4 
            link_colors_rgba = [
                begin
                    hex = node_colors[src]  # Get the source node color
                    c = parse(Colorant, hex)
                    r, g, b = round.(Int, (red(c), green(c), blue(c)) .* 255)
                    "rgba($r,$g,$b,$opacity)"
                end
                for src in Sources
                ]

            # Step 2: Scenario name annotations using Dict()
            annotations = [
                Dict(
                    :x => 0.07,  # x position for Scenario 1
                    :y => 1.05,  # y position slightly above the nodes
                    :text => "$(Annotation_1)",  # Text for the annotation
                    :showarrow => false,
                    :font => Dict(:size => 20, :color => "black"),
                    :align => "center"
                ),
                Dict(
                    :x => 1.02, # x position for Scenario 2
                    :y => 1.05,  # y position slightly above the nodes
                    :text => "$(Annotation_2)",
                    :showarrow => false,
                    :font => Dict(:size => 20, :color => "black"),
                    :align => "center"
                )
            ]

        
            Pos_x = vcat(fill(0.1, 5), fill(0.99, n_labels))      # you can not use values equal to zero or one. 
            Pos_y = [0.1, 0.44, 0.81, 0.923, 0.99,    0.86, 0.925, 0.99, 0.42]
            # Step 7: Plot it!         
            fig = go.Figure(go.Sankey(
                    node=Dict(
                        :label=>Labels_3,
                        :x=>Pos_x,
                        :y=>Pos_y,
                        :color=>node_colors,
                        :pad=>5,
                        :thickness=>20,
                    ),
                    link=Dict(
                        :source=>Sources .- 1,  # Plotly expects 0-based!
                        :target=>Targets .- 1,
                        :value=>Values,
                        :color=>link_colors_rgba)),
                layout=Dict(
                    :annotations=>annotations  # Add the scenario name annotation
                ))
                





        #         y_left = range(0.001, stop=0.999, length=n_labels)
        #         y_right = range(0.001, stop=0.999, length=n_labels)
        #         y_positions = vcat(y_left, y_right)

        #         trace = PlotlyJS.sankey(
        #             arrangement="snap",
        #             node=attr(
        #                 label=Labels_3,
        #                 x=Pos_x,
        #                 y=y_positions,
        #                 color=node_colors,
        #                 pad=5,
        #                 thickness=20,
        #             ),
        #             link=attr(
        #                 source=Sources .-1,  # Plotly expects 0-based!
        #                 target=Targets .-1,
        #                 value=Values,
        #                 color=link_colors_rgba), 
        #         layout=Dict(
        #             :annotations=>annotations  # Add the scenario name annotation
        #         ))
        # display(PlotlyJS.plot(trace, Layout(title="Test Sankey")))
        end 

        fig.update_layout(
        # title_text="Basic Sankey Diagram",
        font_family="STIXGeneral",
        font_color="black",
        font_size=20,
        title_font_family="STIXGeneral",
        # title_font_color="red",
        )

        # save_path = "./Figures/$(Figure_name).png"
        # savefig(fig,save_path)
        fig.show()
    else 
        skip 
    end
    # plotlyio.write_image(fig, "test.png")
    return  DF_sankey
end

py"""
def geo_coverage(NUTS_level,codes,shapefile):
    import pandas as pd
    import geopandas as gpd
    NUTS_ = gpd.read_file(shapefile)
    NUTS_codes = {}
    trilateral_ = gpd.GeoDataFrame()
    for code in codes:  
        if code in list(NUTS_.CNTR_CODE):
            NUTS_codes[code] = NUTS_.loc[(NUTS_.CNTR_CODE == code) & (NUTS_.LEVL_CODE==NUTS_level)]
        else:
            NUTS_codes[code] = NUTS_.loc[(NUTS_.NUTS_ID.str.contains(code)) & (NUTS_.LEVL_CODE==NUTS_level)]       
        trilateral_ = pd.concat([trilateral_,NUTS_codes[code]])
    trilateral_.reset_index(drop=True,inplace=True)
    return trilateral_
""" 

py"""
def draw_pie(dist, xpos, ypos, size, ax, colors_pie):
    import numpy as np
    cumsum = np.cumsum(dist)
    cumsum = cumsum / cumsum[-1]
    pie = [0] + cumsum.tolist()

    #ax.scatter([xpos], [ypos], marker="o", s=size+2, edgecolors = "black", color="white", alpha=1,  linewidths=2)
    ax.scatter([xpos], [ypos], marker="o", s=(size+5)*1.1, edgecolors = "black", facecolors="none", alpha = 1, linewidths=0.5)

    for i, (r1, r2) in enumerate(zip(pie[:-1], pie[1:])):
        if r2 - r1 <= 1e-6:
            continue  # skip near-zero slices
        angles = np.linspace(2 * np.pi * r1, 2 * np.pi * r2)
        x = [0] + np.cos(angles).tolist()
        y = [0] + np.sin(angles).tolist()
        xy = np.column_stack([x, y])
        ax.scatter([xpos], [ypos], marker=xy, s=size, color=colors_pie[i], alpha=0.4)

"""



py"""
def scale_capture_volume(min_size,max_size,capture_volume):
    
    # Normalizing the series to range [10, 20]
    s_normalized = min_size + ( (capture_volume - capture_volume.min()) * (max_size - min_size) ) / (capture_volume.max() - capture_volume.min())
    
    return s_normalized
"""

function visualisation_pipes(shapefile_eu, Scenario_name::String, Subcase_name::String)

     Emitters = import_data_industry(CO2_tax::Any, Scenario_name::String, Scenario_horizon::Int64) #, (load_data=true; load_data))

    include("parameters.jl")    # run all the parameters of the script
 
    # Plotting

    fig, ax = plt.subplots(figsize=(8, 16))


    if Region == "Trilateral"
        if France == true
            trilateral= py"geo_coverage"(NUTS_level=2,codes=["NL","BE","DEA","FRE1","FRE2"],shapefile =shapefile_eu)
            clusters_trilateral = py"geo_coverage"(NUTS_level=2,codes=["NL","BE","DEA","FRE1","FRE2", "FRD2"],shapefile =shapefile_eu)
            borders = py"geo_coverage"(NUTS_level=0,codes=["NL","BE","DEA","FRE1","FRE2"],shapefile =shapefile_eu)
            non_trilateral= py"geo_coverage"(NUTS_level=2,codes=["FR","DE"],shapefile =shapefile_eu)
            non_trilateral_2= py"geo_coverage"(NUTS_level=2,codes=["FR","DE", "NO", "SE", "DK", "LU"],shapefile =shapefile_eu)
            other_borders = py"geo_coverage"(NUTS_level=0,codes=["FR","DE", "NO", "DK", "SE"],shapefile =shapefile_eu)
            borders_NRW = py"geo_coverage"(NUTS_level=1,codes=["DEA", "FRE"],shapefile =shapefile_eu)

            # Regions
            # trilateral.boundary.plot(ax=ax, linewidth=0.2,color="black") # no provinces
            non_trilateral_2.plot(ax=ax, color="lightgrey", edgecolor="none", zorder=0)
            borders_NRW.plot(ax=ax, color="white", edgecolor="none", zorder=0)

            borders.boundary.plot(ax=ax, linewidth=0.9,color="black")
            # non_trilateral.boundary.plot(ax=ax, linewidth=0.2,color="grey")
            other_borders.boundary.plot(ax=ax, linewidth=0.3,color="grey")
            borders_NRW.boundary.plot(ax=ax, linewidth=0.9,color="black")
        else
            trilateral= py"geo_coverage"(NUTS_level=2,codes=["NL","BE","DEA"],shapefile =shapefile_eu)
            clusters_trilateral = trilateral
            borders = py"geo_coverage"(NUTS_level=0,codes=["NL","BE","DEA"],shapefile =shapefile_eu)
            non_trilateral= py"geo_coverage"(NUTS_level=2,codes=["FR","DE"],shapefile =shapefile_eu)
            non_trilateral_2= py"geo_coverage"(NUTS_level=2,codes=["FR","DE", "NO", "SE", "DK", "LU"],shapefile =shapefile_eu)
            other_borders = py"geo_coverage"(NUTS_level=0,codes=["FR","DE", "NO", "DK", "SE"],shapefile =shapefile_eu)
            borders_NRW = py"geo_coverage"(NUTS_level=1,codes=["DEA"],shapefile =shapefile_eu)

            # Regions
            # trilateral.boundary.plot(ax=ax, linewidth=0.2,color="black") # no provinces
            non_trilateral_2.plot(ax=ax, color="lightgrey", edgecolor="none", zorder=0)
            borders_NRW.plot(ax=ax, color="white", edgecolor="none", zorder=0)

            borders.boundary.plot(ax=ax, linewidth=0.9,color="black")
            # non_trilateral.boundary.plot(ax=ax, linewidth=0.2,color="grey")
            other_borders.boundary.plot(ax=ax, linewidth=0.3,color="grey")
            borders_NRW.boundary.plot(ax=ax, linewidth=0.9,color="black")
        end 
    elseif Region == "Europe"
        NUTS_ = gpd.read_file(shapefile_eu)
        non_trilateral= py"geo_coverage"(NUTS_level=2,codes=unique(NUTS_["CNTR_CODE"]),shapefile =shapefile_eu)
        other_borders = py"geo_coverage"(NUTS_level=0,codes=unique(NUTS_["CNTR_CODE"]),shapefile =shapefile_eu)
        #  clusters_trilateral = trilateral

        non_trilateral.boundary.plot(ax=ax, linewidth=0.2,color="grey")
        other_borders.boundary.plot(ax=ax, linewidth=0.3,color="grey")

    else
    end






    # Candidate Pipelines
        
    system_data_file =   eval(Symbol("system_data_file_", detail_level))
    Intercept = true  # True: binary variables for pipeline investments, false: no binary parameters for pipeline investments 
    global Costs, Routing_nodes_all, Pipelines_all, Terminals, Storage_offshore, Storage_inland, Offshore_nodes, Clusters = import_data_TandS(system_data_file) 
    include("parameters.jl")    # run all the parameters of the script 
    global Pipes_opt_co_na, Pipes_opt_sizes = pipeline_results_extract(Scenario_name::String, Subcase_name::String, CO2_tax::Int64)
    # scenario_title = Scenario_title_vect[i]
    global Industry_connection_results = industry_results_extract(Scenario_name::String, Subcase_name::String, CO2_tax::Int64)

    capacity_cutout = 0.008
    cmap_style = "winter_r"
    v_min = 1
    try 
        global v_max =  maximum(Pipes_opt_sizes) # 250
    catch 
        global v_max = v_min
    end
    sm = plt.cm.ScalarMappable(cmap=cmap_style, norm=plt.Normalize(vmin=1, vmax=v_max))
    sm.set_array([])

    for pipe in Pipe_coordinates
        plt.plot(
            [pipe[1,1], pipe[2,1]],
            [pipe[1,2], pipe[2,2]],
            "--",  # Dashed line for candidate connections
            color="dimgrey",
            alpha = 0.5, 
            linewidth=0.5, # original 0.5
            label="Candidate connection")
    end

    triangle_marker = Line2D([0], [0], marker="^", color="w", label="Storage sites", markerfacecolor="brown", markersize=8)  # need to use some mathmode otherwise italic text            
    Storage_capacity_marker = Line2D([0], [0], markersize=14, marker="o", lw=0, markeredgecolor="black",  color= "white", alpha = 0.5, label="Storage fields") #sm.to_rgba(v_max)
    dashed_line = Line2D([0], [0],markersize=14, linestyle="--", color="grey", lw=1.5, label="Candidate connections")
    full_line = Line2D([0], [0], markersize=14,linestyle="-", color="mediumseagreen", lw=2, label="Selected connection")
    capture_marker = Line2D([0], [0], markersize=14,marker="o", lw=0, alpha = 0.5,  color=sm.to_rgba(v_min),  label="CCS participant")
    non_capture_marker = Line2D([0], [0], markersize=14,marker="o", lw=0, alpha = 0.5, color="indianred",  label="CCS nonparticipant")
    emitter_marker = Line2D([0], [0], markersize=14,marker=".", lw=0,  color="black", label="Non-CCS sites (default)")
    centroids = Line2D([0], [0], markersize=14,marker="x", lw=0,  color="dimgrey", label="Cluster centroids")
    terminal_marker = Line2D([0], [0],markersize=14, marker="s", lw=0,  color="grey", label="Terminals")
    # Optimal pipelines
    
    for index in 1:length(Pipes_opt_co_na)
        pipe_opt_coordinates = values.(Pipes_opt_co_na)[index][:]
        pipe_opt_cap = values.(Pipes_opt_sizes)[index]
        # arrow = FancyArrowPatch(
        #     (pipe_opt_coordinates[1], pipe_opt_coordinates[3]),
        #     (pipe_opt_coordinates[2], pipe_opt_coordinates[4]),
        #     arrowstyle="-",
        #     mutation_scale=20.0, # 12
        #     color=py"getattr"(plt.cm,cmap_style)(pipe_opt_cap / v_max),  # Use 'viridis_r' colormap
        #     alpha=0.7,
        #     lw=2 #,         transform=ax.transData,
        # )
        # ax.add_patch(arrow) #https://matplotlib.org/stable/api/_as_gen/matplotlib.patches.ConnectionStyle.html#matplotlib.patches.ConnectionStyle

   
    end

    all_pipe_opt_coordinates = values.(Pipes_opt_co_na)[:][:];
    all_pipe_opt_cap = values.(Pipes_opt_sizes)[:]
    indices_to_keep = findall(x -> x >= 0.0, all_pipe_opt_cap)
    filtered_pipe_opt_cap = all_pipe_opt_cap[indices_to_keep]
    filtered_pipe_opt_coordinates = all_pipe_opt_coordinates[indices_to_keep]
    segments = [[(filtered_pipe_opt_coordinates[i][1], filtered_pipe_opt_coordinates[i][3]), (filtered_pipe_opt_coordinates[i][2], filtered_pipe_opt_coordinates[i][4])] for i in 1:length(filtered_pipe_opt_coordinates)] 
    lc = LineCollection(segments, cmap=cmap_style, norm=plt.Normalize(vmin=0, vmax=v_max), alpha= 0.7, lw=2.2, capstyle="round",   # rounded line ends # original lw = 1.5
    joinstyle="round"   # rounded corners where segments meet
    )
    lc.set_array(filtered_pipe_opt_cap)
    

    # Clusters 


    Trilateral_area = clusters_trilateral["geometry"]
    inside = [any(geom.contains(shpgeo.Point(row.Lon, row.Lat)) for geom in Trilateral_area)
    for row in eachrow(Cluster_coordinates_plot)]
    Clusters_inside = Cluster_coordinates_plot[inside, :]

    scatter_plot = plt.scatter(
        Clusters_inside[:,2],
        Clusters_inside[:,1],
        s=25, #original: 15
        #label='Target Regions',
        marker = "x",
        lw=2.0,
        color="dimgrey"
    )
    # Terminals 
    scatter = plt.scatter(
        Terminal_coordinates[:,2],
        Terminal_coordinates[:,1],
        s=20, # original 10
        color="grey",
        marker="s",
    )
    Industry_connection_results = industry_results_extract(Scenario_name::String, Subcase_name::String, CO2_tax::Int64)
    cc_emitter_extract =  Dict(e => try Industry_connection_results[Industry_connection_results[:, "Emitters"] .== e, "Bin_connection"][1] catch skip end for e in EMITTERS)
    

    # Emitters 
    capture_volume_dict = Dict(e => TOT_capture_1_CO2[e].*cc_emitter_extract[e] for e in EMITTERS)
    Emitters_modelled = Dict(e =>  (Emitters[Emitters[:,"Emitter_id"] .==e, "Lon"][1],  Emitters[Emitters[:,"Emitter_id"] .==e, "Lat"][1]) for e in EMITTERS)
    # filtered_emitters = filter(kv -> kv[2] != (0, 0), Emitters_modelled)
    Emitters_captured = Dict(e => Emitters_modelled[e] for e in EMITTERS if cc_emitter_extract[e] != 0)
    Emitters_cancelled = Dict(e => Emitters_modelled[e] for e in EMITTERS if(cc_emitter_extract[e] == 0) &(TOT_capture_1_CO2[e] != 0))
    Emitters_cancelled_names = [Emitters[Emitters[:,"Emitter_id"] .==k, "Product_route_name"][1] for (k, v) in zip(keys(Emitters_cancelled),Emitters_cancelled)]
    Non_capture_sites = Dict(e => Emitters_modelled[e] for e in EMITTERS if TOT_capture_1_CO2[e] == 0)

    


    # capture_volume_vect = [TOT_capture_1_CO2[e].*cc_emitter_extract[e] for e in EMITTERS]

    capture_volume_vect = [TOT_capture_1_CO2[e] for e in EMITTERS] 
    min_size = 10 # original: 1
    max_size = 70 * maximum(capture_volume_vect) # original: 30
    normalised_cc_vol_vect = py"scale_capture_volume"(min_size,max_size,capture_volume_vect)
    normalised_cc_vol_dict = Dict(e => normalised_cc_vol_vect[i] for  (i,e) in enumerate(EMITTERS))
    cc_vol_dict =  Dict(e => capture_volume_vect[i] for  (i,e) in enumerate(EMITTERS))
    #capture_volume_vect_cancelled = [TOT_capture_1_CO2[e].*(1-cc_emitter[e]) for e in EMITTERS]
    # normalised_cc_vol_vect_cancelled_with_NaN= py"scale_capture_volume"(min_size,max_size,capture_volume_vect_cancelled)
    # normalised_cc_vol_vect_cancelled = replace(normalised_cc_vol_vect_cancelled_with_NaN, NaN => 0.0)

    normalised_cc_vol_dict_cancelled = Dict(e => normalised_cc_vol_vect[i] for  (i,e) in enumerate(EMITTERS))



    # capturing emitters 
    # all emitters
    # for e in 1:length(Emitters[:, "Emitter_id"])
    #     scatter = plt.scatter(
    #         Emitters[e, "Lon"],
    #         Emitters[e, "Lat"],
    #         #label='Target Regions',
    #         s = 0.5,
    #         color="black"
    #     )
    # end 

    
    for e in EMITTERS
        try # All emitters trilateral region
            scatter = plt.scatter(
                Emitters[e][1],
                Emitters[e][2],
                #label='Target Regions',
                s = 2, # original: 0.5
                color="black"
            )
        catch 
        end
        try # Assigning green color to all connected carbon capture sites 
            scatter = plt.scatter(
                Emitters_captured[e][1],
                Emitters_captured[e][2],
                #label='Target Regions',
                s = 4, #original: 2
                color=sm.to_rgba(cc_vol_dict[e])
            )
        catch 
        end
        try # Assigning green color size to all sites 
        scatter = plt.scatter(
            Emitters_captured[e][1],
            Emitters_captured[e][2],
            s=normalised_cc_vol_dict[e],
            #label='Target Regions',
            color=sm.to_rgba(cc_vol_dict[e]),
            alpha= 0.5,
        )
        catch 
        end

    end
    for e in EMITTERS
        try # Assigning red color to all cancelled carbon capture sites 
            scatter = plt.scatter(
                Emitters_cancelled[e][1],
                Emitters_cancelled[e][2],
                #label='Target Regions',
                s = 4, # original: 2
                color="indianred"
            )
        catch 
        end

        try # assigning red color to all disconnected carbon capture sites 
        scatter = plt.scatter(
            Emitters_cancelled[e][1],
            Emitters_cancelled[e][2],
            s=normalised_cc_vol_dict_cancelled[e],
            #label='Target Regions',
            color="indianred",
            alpha= 0.5,
        )
        # if e == "E2574"
        #      plt.annotate(e, (Emitters_cancelled[e][1], Emitters_cancelled[e][2]), textcoords = "offset points", xytext = (5,5), ha="center")
        # end
        catch 
        end

        try # assigning blue color to all no carbon capture sites
        scatter = plt.scatter(
            Non_capture_sites[e][1],
            Non_capture_sites[e][2],
            s= 4, # orginal: 2
            #label='Target Regions',
            color="black",
            alpha= 0.5,
        )
        catch 
        end
    end 

    # Storage locations
    # scatter = plt.scatter(
    #     Storage_offshore_coordinates[:,2],
    #     Storage_offshore_coordinates[:,1],
    #     s=30, # original: 15
    #     color="brown",
    #     marker="^",
    # )

    # scatter = plt.scatter(
    #     Storage_inland_coordinates[:,2],
    #     Storage_inland_coordinates[:,1],
    #     s=30, # original: 15
    #     color="brown",
    #     marker="^",
    # )



    # Storages 
    max_cap  =  20.0 #maximum(Cluster_capture_summary[!,"Total_capture_potential_sum"]) # original 
    size_scale = 0.8  # you can adjust this to control absolute pie size # original: 0.2
    base_size = 1000 # you can adjust this to control absolute pie size # original: 600
    Storage_summary_df = storage_results_extract(Scenario_name::String, Subcase_name::String, CO2_tax::Int64)
    for i in 1:nrow(Storage_summary_df)
        lon = Storage_summary_df.Lon[i]
        lat = Storage_summary_df.Lat[i]
        
        Full = Storage_summary_df.Stored_vol_node_origin[i]
        Empty = Storage_summary_df.Theoretical_volume_mt[i]./Storage_periods - Storage_summary_df.Stored_vol_node_origin[i]
        sizes = [Full, Empty]
        total = sum(sizes)
        if total == 0
            continue  # skip empty pies
        end


        # Compute pie size (relative to total)
        pie_radius = size_scale * sqrt(total / max_cap)

        size = base_size * (total / max_cap)

        # Call Python function
        global colors_pie = [sm.to_rgba(Full), "white"]
        py"draw_pie"(sizes, lon, lat, size, ax, colors_pie)



        # # Create new inset axes at cluster location
        # bbox = [lon - pie_radius, lat - pie_radius, 2*pie_radius, 2*pie_radius]
        # inset_ax = fig.add_axes(bbox, transform=ax[2].transData, zorder=5)  # Data-coord inset
        # inset_ax.pie(sizes, colors=["green", "brown", "indianred"])
        # inset_ax.set_aspect("equal")
        # inset_ax.axis("off")
    end


    # show plot 
    plt.legend(handles=[dashed_line, full_line, emitter_marker, capture_marker, non_capture_marker, centroids, terminal_marker, Storage_capacity_marker], title_fontsize=6.5, fontsize=18, loc="upper right") #bbox_to_anchor=(0.55,0)



    # cbar = plt.colorbar(sm,ax =ax, label="CO2 network infrastructure",shrink=0.2)

    ax.spines["top"].set_visible(false)    # Remove top border
    ax.spines["right"].set_visible(false)  # Remove right border
    ax.spines["bottom"].set_visible(false) # Remove bottom border
    ax.spines["left"].set_visible(false)   # Remove left border

    ax.set_xlabel("")  # Remove X-axis title
    ax.set_ylabel("")  # Remove Y-axis title

    # Remove X-axis and Y-axis tick labels
    ax.set_xticks([])
    ax.set_yticks([])


    # Axis limits 
    ## Regional 
    if Region == "Trilateral"
        # ax.set_xlim([1,11])
        # ax.set_ylim([48,60])
        if (Scenario_name == "CDR_price" || Scenario_name == "Exit_no_CDR") && Social_decision == true 
            ax.set_xlim([1,11])
            ax.set_ylim([49.3,57])
            cax_legpos = [0.78, 0.29, 0.02, 0.2]
 
        elseif Social_decision == false 
            ax.set_xlim([1,11])
            ax.set_ylim([48.3,61])
            cax_legpos = [0.78, 0.15, 0.02, 0.2]

        else
            if France == true
                cax_legpos = [0.78, 0.15, 0.02, 0.2]
                ax.set_xlim([1,11])
                ax.set_ylim([48.7,61])
            else
                if UK_storage == true 
                    cax_legpos = [0.79, 0.20, 0.02, 0.2]
                    ax.set_xlim([0,11])
                    ax.set_ylim([49.3,61])
                else 
                    cax_legpos = [0.78, 0.15, 0.02, 0.2]
                    ax.set_xlim([1,11])
                    ax.set_ylim([49.3,61])
                end
            end
        end
    elseif Region == "Europe"
        ## European 
        cax_legpos = [0.78, 0.15, 0.02, 0.2]
        ax.set_xlim([-10,25])
        ax.set_ylim([38,60])
    else 
        print("Error - region coordinates not defined")
    end


    ax.add_collection(lc)
    if Scenario_name != "Exit_no_CDR"
        c_ax = fig.add_axes(cax_legpos)   
        cbar = plt.colorbar(lc,cax =c_ax, shrink=0.2)
        vmin, vmax = lc.norm.vmin, lc.norm.vmax
        vmin_r = Int64(5 * round(vmin / 5))
        vmax_r =  Int64(round(vmax,digits =0))
        vmid_r = Int64(5 * round((vmin_r + vmax_r) / 10))

        cbar.set_ticks([vmin_r, vmid_r, vmax_r])
        #cbar.ax.set_ylabel("Pipe capacity (MtCO2pa)",size=8)
        cbar.ax.set_ylabel(L"Injection capacity (MtCO$_2$pa)", size=18)
        cbar.ax.yaxis.set_tick_params(labelsize=18)
        # ax.set_xlabel("Longitude")
        # ax.set_ylabel("Latitude")
    else
        skip
    end

    # Remove X-axis and Y-axis tick marks (grid lines)
    ax.tick_params(axis="both", which="both", length=0)
    if Social_decision == true
        additional_title_info = "CC, T&S optimised"
    else
        additional_title_info = "CC max, T&S optimised"
    end

    # Table_parameters = Key_output_df.Parameters
    # Table_values = Key_output_df.Values
    # Table_units = Key_output_df.Unit
    # Table_matrix = hcat(Table_parameters, Table_values, Table_units)
    # plt.table(cellText=Table_matrix, colLabels=["Parameter", "Value", "Unit"], loc="bottom", cellLoc="center")
    # plt.subplots_adjust(bottom=0.3)

    plt.title("", pad=25,fontsize=14)
    #plt.tight_layout()
    if MPEC == true 
        save_path = "./Figures/MPEC/$(Scenario_name)_$(CO2_tax)_$(Subcase_name).svg"
    else
        save_path = "./Figures/Base/$(Scenario_name)_$(CO2_tax)_$(Subcase_name).svg"
    end

    plt.savefig(save_path, bbox_inches="tight")




    # plt.show()
return     # plt.show()
end


function preOpt_visualisation_py(shapefile_eu)
    
    
    # Plotting

    fig, ax = plt.subplots(figsize=(8, 16))
    divider = make_axes_locatable(ax)

        

    
    if Region == "Trilateral"
        trilateral= py"geo_coverage"(NUTS_level=2,codes=["NL","BE","DEA"],shapefile =shapefile_eu)
        borders = py"geo_coverage"(NUTS_level=0,codes=["NL","BE","DEA"],shapefile =shapefile_eu)
        non_trilateral= py"geo_coverage"(NUTS_level=2,codes=["FR","DE"],shapefile =shapefile_eu)
        non_trilateral_2= py"geo_coverage"(NUTS_level=2,codes=["FR","DE", "NO", "SE", "DK", "LU"],shapefile =shapefile_eu)
        other_borders = py"geo_coverage"(NUTS_level=0,codes=["FR","DE", "NO", "DK", "SE"],shapefile =shapefile_eu)
        borders_NRW = py"geo_coverage"(NUTS_level=1,codes=["DEA"],shapefile =shapefile_eu)
        # Regions

        # trilateral.boundary.plot(ax=ax, linewidth=0.2,color="black") # no provinces
        non_trilateral_2.plot(ax=ax, color="lightgrey", edgecolor="none", zorder=0)
        borders_NRW.plot(ax=ax, color="white", edgecolor="none", zorder=0)
        # Regions
        trilateral.boundary.plot(ax=ax, linewidth=0.2,color="black") #  provinces
        borders.boundary.plot(ax=ax, linewidth=0.7,color="black")
        non_trilateral.boundary.plot(ax=ax, linewidth=0.2,color="grey")
        other_borders.boundary.plot(ax=ax, linewidth=0.3,color="grey")
        borders_NRW.boundary.plot(ax=ax, linewidth=0.7,color="black")

    elseif Region == "Europe"
        NUTS_ = gpd.read_file(shapefile_eu)
        non_trilateral= py"geo_coverage"(NUTS_level=2,codes=unique(NUTS_["CNTR_CODE"]),shapefile =shapefile_eu)
        other_borders = py"geo_coverage"(NUTS_level=0,codes=unique(NUTS_["CNTR_CODE"]),shapefile =shapefile_eu)

        non_trilateral.boundary.plot(ax=ax, linewidth=0.2,color="grey")
        other_borders.boundary.plot(ax=ax, linewidth=0.3,color="grey")

    else
    end

    # Candidate Pipelines
    system_data_file =   eval(Symbol("system_data_file_", detail_level))
    Intercept = true  # True: binary variables for pipeline investments, false: no binary parameters for pipeline investments 
    global Costs, Routing_nodes_all, Pipelines_all, Terminals, Storage_offshore, Storage_inland, Offshore_nodes, Clusters = import_data_TandS(system_data_file) 
    include("parameters.jl")    # run all the parameters of the script 
    global Pipes_opt_co_na, Pipes_opt_sizes = pipeline_results_extract(Scenario_name::String, Subcase_name::String, CO2_tax::Int64)
    global Industry_connection_results = industry_results_extract(Scenario_name::String, Subcase_name::String, CO2_tax::Int64)

    capacity_cutout = 0.008
    cmap_style = "winter_r"
    v_min = 1
    v_max =  maximum(Pipes_opt_sizes) # 250




    triangle_marker = Line2D([0], [0], marker="o", lw=0, markeredgecolor="black", label="Geological storage", markerfacecolor="white", markersize=8)              
    dashed_line = Line2D([0], [0], linestyle="--", color="grey", lw=1.5, label="Candidate connection")
    full_line = Line2D([0], [0], linestyle="-", color="mediumseagreen", lw=2, label="Selected connection")
    capture_marker = Line2D([0], [0], marker="o", lw=0, alpha = 0.5,  color="mediumseagreen",  label="CCS participant")
    non_capture_marker = Line2D([0], [0], marker="o", lw=0, alpha = 0.5, color="indianred",  label="CCS nonparticipant")
    emitter_marker = Line2D([0], [0], marker=".", lw=0,  color="black", label="Emitter (all)")
    chemical_emitters = Line2D([0], [0], marker="o", lw=0,  color="chocolate", label="Chemicals (Olefins, PE, PEA)")
    fertiliser_emitters = Line2D([0], [0], marker="s", lw=0,  color="goldenrod", label="Fertiliser (ammonia, urea, nitric acid)")
    refinery_emitters = Line2D([0], [0], marker="P", lw=0,  color="darkred", label="Refineries")
    steel_emitters = Line2D([0], [0], marker="v", lw=0,  color="limegreen", label="Steel (primary, secondary)")
    cement_emitters = Line2D([0], [0], marker="d", lw=0,  color="darkblue", label="Cement")
    glass_emitters = Line2D([0], [0], marker="^", lw=0,  color="mediumvioletred", label="Glass")

    terminal_marker = Line2D([0], [0], marker="s", lw=0,  color="grey", label="Terminals")
    centroids = Line2D([0], [0], marker="x", lw=0,  color="dimgrey", label="Cluster entroids")
    # Optimal pipelines



    # Clusters 
    sm = plt.cm.ScalarMappable(cmap=cmap_style, norm=plt.Normalize(vmin=1, vmax=v_max))
    sm.set_array([])

    # Storage locations
    # scatter = plt.scatter(
    #     Storage_offshore_coordinates[:,2],
    #     Storage_offshore_coordinates[:,1],
    #     s=15,
    #     color="brown",
    #     marker="^",
    # )

    # scatter = plt.scatter(
    #     Storage_inland_coordinates[:,2],
    #     Storage_inland_coordinates[:,1],
    #     s=15,
    #     color="brown",
    #     marker="^",
    # )

     max_cap  =  20.0 #maximum(Cluster_capture_summary[!,"Total_capture_potential_sum"]) # original 
    size_scale = 0.8  # you can adjust this to control absolute pie size # original: 0.2
    base_size = 1000 # you can adjust this to control absolute pie size # original: 600
    Storage_summary_df = storage_results_extract(Scenario_name::String, Subcase_name::String, CO2_tax::Int64)
    for i in 1:nrow(Storage_summary_df)
        lon = Storage_summary_df.Lon[i]
        lat = Storage_summary_df.Lat[i]
        
        Full = 0.0
        Empty = Storage_summary_df.Theoretical_volume_mt[i]./Storage_periods - Storage_summary_df.Stored_vol_node_origin[i]
        sizes = [0.0, Empty]
        total = sum(sizes)
        if total == 0
            continue  # skip empty pies
        end


        # Compute pie size (relative to total)
        pie_radius = size_scale * sqrt(total / max_cap)

        size = base_size * (total / max_cap)

        # Call Python function
        global colors_pie = ["white", "white"]
        py"draw_pie"(sizes, lon, lat, size, ax, colors_pie)



        # # Create new inset axes at cluster location
        # bbox = [lon - pie_radius, lat - pie_radius, 2*pie_radius, 2*pie_radius]
        # inset_ax = fig.add_axes(bbox, transform=ax[2].transData, zorder=5)  # Data-coord inset
        # inset_ax.pie(sizes, colors=["green", "brown", "indianred"])
        # inset_ax.set_aspect("equal")
        # inset_ax.axis("off")
    end


    scatter = plt.scatter(
        Terminal_coordinates[:,2],
        Terminal_coordinates[:,1],
        s=10,
        color="grey",
        marker="s",
    )

    scatter_plot = plt.scatter(
        Cluster_coordinates[:,2],
        Cluster_coordinates[:,1],
        s=15,
        #label='Target Regions',
        marker = "x",
        lw=1.0,
        color="dimgrey"
    )



    # capturing emitters 
    # all emitters

    
    for e in intersect(unique(Chemical_emitters[:, "Emitter_id"]), EMITTERS)
        scatter = plt.scatter(
            Chemical_emitters[Chemical_emitters[:, "Emitter_id"] .== e, "Lon"],
            Chemical_emitters[Chemical_emitters[:, "Emitter_id"] .== e, "Lat"],
            #label='Target Regions',
            s = 8,
            marker="o", 
            color="chocolate"
        )
    end 
    for e in intersect(unique(Fertilisers_emitters[:, "Emitter_id"]), EMITTERS)
        scatter = plt.scatter(
            Fertilisers_emitters[Fertilisers_emitters[:, "Emitter_id"] .== e, "Lon"],
            Fertilisers_emitters[Fertilisers_emitters[:, "Emitter_id"] .== e, "Lat"],
            #label='Target Regions',
            s = 8,
            marker="s", 
            color="goldenrod"
        )
    end 
    for e in intersect(unique(Refineries_emitters[:, "Emitter_id"]), EMITTERS)
        scatter = plt.scatter(
            Refineries_emitters[Refineries_emitters[:, "Emitter_id"] .== e, "Lon"],
            Refineries_emitters[Refineries_emitters[:, "Emitter_id"] .== e, "Lat"],
            #label='Target Regions',
            s = 8,
            marker="P", 
            color="darkred"
        )
    end
    
    for e in intersect(unique(Cement_emitters[:, "Emitter_id"]), EMITTERS)
        scatter = plt.scatter(
            Cement_emitters[Cement_emitters[:, "Emitter_id"] .== e, "Lon"],
            Cement_emitters[Cement_emitters[:, "Emitter_id"] .== e, "Lat"],
            #label='Target Regions',
            s = 8,
            marker="d", 
            color="darkblue"
        )
    end 

    for e in intersect(unique(Steel_emitters[:, "Emitter_id"]), EMITTERS)
        scatter = plt.scatter(
            Steel_emitters[Steel_emitters[:, "Emitter_id"] .== e, "Lon"],
            Steel_emitters[Steel_emitters[:, "Emitter_id"] .== e, "Lat"],
            #label='Target Regions',
            s = 8,
            marker="v", 
            color="limegreen"
        )
    end 

    for e in intersect(unique(Glass_emitters[:, "Emitter_id"]), EMITTERS)
        scatter = plt.scatter(
            Glass_emitters[Glass_emitters[:, "Emitter_id"] .== e, "Lon"],
            Glass_emitters[Glass_emitters[:, "Emitter_id"] .== e, "Lat"],
            #label='Target Regions',
            s = 8,
            marker="^", 
            color="mediumvioletred"
        )
    end 

    for e in 1:length(Emitters[:, "Emitter_id"])
        scatter = plt.scatter(
            Emitters[e, "Lon"],
            Emitters[e, "Lat"],
            #label='Target Regions',
            s = 0.3,
            color="black"
        )
    end 

    

    for (i,pipe) in enumerate(Pipe_coordinates)
        plt.plot(
            [pipe[1,1], pipe[2,1]],
            [pipe[1,2], pipe[2,2]],
            "--",  # Dashed line for candidate connections
            color="dimgrey",
            alpha = 0.5, 
            linewidth=0.5,
            label="Candidate connection")
        # plt.annotate(Pipe_id[i][1], (pipe[1,1],pipe[1,2]), textcoords = "offset points", xytext = (1,1), ha="center", color = "black")
        # plt.annotate(Pipe_id[i][2], (pipe[2,1],pipe[2,2]), textcoords = "offset points", xytext = (1,1), ha="center", color = "black") 
    end



#     Terminal_id = string.(Terminals[!, "Node_id"])
# Terminal_coordinates = [Terminals[!, "Lat"] Terminals[!, "Lon"]] 

    # show plot 


    ax.set_xlabel("Longitude")
    ax.set_ylabel("Latitude")

    # cbar = plt.colorbar(sm,ax =ax, label="CO2 network infrastructure",shrink=0.2)

    ax.spines["top"].set_visible(false)    # Remove top border
    ax.spines["right"].set_visible(false)  # Remove right border
    ax.spines["bottom"].set_visible(false) # Remove bottom border
    ax.spines["left"].set_visible(false)   # Remove left border

    ax.set_xlabel("")  # Remove X-axis title
    ax.set_ylabel("")  # Remove Y-axis title

    # Remove X-axis and Y-axis tick labels
    ax.set_xticks([])
    ax.set_yticks([])


    # Axis limits 
    if Region == "Trilateral"
        ax.set_xlim([1,11])
        ax.set_ylim([49,57])
    elseif Region == "Europe"
        ## European 
        ax.set_xlim([-10,25])
        ax.set_ylim([38,60])
    else 
        print("Error - region coordinates not defined")
    end

    # Remove X-axis and Y-axis tick marks (grid lines)
    ax.tick_params(axis="both", which="both", length=0)
    # if Social_decision == true
    #     additional_title_info = "CC, T&S optimised"
    # else
    #     additional_title_info = "CC max, T&S optimised"
    # end
    additional_title_info = "Candidate network"
    plt.legend(handles=[chemical_emitters, fertiliser_emitters, refinery_emitters, steel_emitters, cement_emitters, glass_emitters, triangle_marker, terminal_marker, centroids, dashed_line, emitter_marker], loc="upper center", fontsize=10, ncol=2)

    # Table_parameters = Key_output_df.Parameters
    # Table_values = Key_output_df.Values
    # Table_units = Key_output_df.Unit
    # Table_matrix = hcat(Table_parameters, Table_values, Table_units)
    # plt.table(cellText=Table_matrix, colLabels=["Parameter", "Value", "Unit"], loc="bottom", cellLoc="center")
    # plt.subplots_adjust(bottom=0.3)

    plt.tight_layout()
    fig.set_layout_engine(layout="tight")

    save_path = "./Figures/Candidate_grid_py.svg"
    plt.savefig(save_path, bbox_inches="tight")

    # plt.show()
return     # plt.show()
end






function visualisation_capture_clusters(Scenario_name::String, CDR_effect::Bool, Legend::Bool)

    Pipes_opt_co_na, Pipes_opt_sizes = pipeline_results_extract(Scenario_name::String, Subcase_name::String, CO2_tax::Int64)
    # scenario_title = Scenario_title_vect[i]
    global Industry_connection_results = industry_results_extract(Scenario_name::String, Subcase_name::String, CO2_tax::Int64)
    global cc_emitter_extract =  Dict(e => try Industry_connection_results[Industry_connection_results[:, "Emitters"] .== e, "Bin_connection"][1] catch skip end for e in EMITTERS)
    

    fig, ax = plt.subplots(1, figsize=(6, 6))
    # divider = make_axes_locatable(ax)
  


    if Region == "Trilateral"
       trilateral= py"geo_coverage"(NUTS_level=2,codes=["NL","BE","DEA"],shapefile =shapefile_eu)
        clusters_trilateral = trilateral
        borders = py"geo_coverage"(NUTS_level=0,codes=["NL","BE","DEA"],shapefile =shapefile_eu)
        non_trilateral= py"geo_coverage"(NUTS_level=2,codes=["FR","DE"],shapefile =shapefile_eu)
        non_trilateral_2= py"geo_coverage"(NUTS_level=2,codes=["FR","DE", "NO", "SE", "DK", "LU"],shapefile =shapefile_eu)
        other_borders = py"geo_coverage"(NUTS_level=0,codes=["FR","DE", "NO", "DK", "SE"],shapefile =shapefile_eu)
        borders_NRW = py"geo_coverage"(NUTS_level=1,codes=["DEA"],shapefile =shapefile_eu)

        # Regions
        # trilateral.boundary.plot(ax=ax, linewidth=0.2,color="black") # no provinces
        non_trilateral_2.plot(ax=ax, color="lightgrey", edgecolor="none", zorder=0)
        borders_NRW.plot(ax=ax, color="white", edgecolor="none", zorder=0)

        borders.boundary.plot(ax=ax, linewidth=0.9,color="black")
        # non_trilateral.boundary.plot(ax=ax, linewidth=0.2,color="grey")
        other_borders.boundary.plot(ax=ax, linewidth=0.3,color="grey")
        borders_NRW.boundary.plot(ax=ax, linewidth=0.9,color="black")
   

    elseif Region == "Europe"
        NUTS_ = gpd.read_file(shapefile_eu)
        non_trilateral= py"geo_coverage"(NUTS_level=2,codes=unique(NUTS_["CNTR_CODE"]),shapefile =shapefile_eu)
        other_borders = py"geo_coverage"(NUTS_level=0,codes=unique(NUTS_["CNTR_CODE"]),shapefile =shapefile_eu)


    else
    end



    capacity_cutout = 0.008
    cmap_style = "winter_r"
    v_min = 1
    v_max =  maximum(Pipes_opt_sizes) # 250

    
    ##############################################"""
    # Subplot 2: pies 
    ################################################

    # Emitters 
    global Emitters = import_data_industry(CO2_tax::Any, Scenario_name::String, Scenario_horizon::Int64) #, (load_data=true; load_data))
    Emitters_capture_info = DataFrame(
        "Emitter_id" => [e for e in EMITTERS], 
        "Cluster_julia" => [Emitters[Emitters[:,"Emitter_id"] .== e, "Cluster_julia"][1] for e in EMITTERS], 
        "Total_Mtpa_bio" => [Emitters[Emitters[:,"Emitter_id"] .== e, "Capture_ofwhich_bio_1_tCO2ptpa"][1]* cc_emitter_extract[e] *TOT_production[e] for e in EMITTERS],
        "Total_Mtpa_fossil" =>[(Emitters[Emitters[:,"Emitter_id"] .== e, "Captured_CO2_1_tCO2ptpa"][1] - Emitters[Emitters[:,"Emitter_id"] .== e, "Capture_ofwhich_bio_1_tCO2ptpa"][1]) * cc_emitter_extract[e] *TOT_production[e] for e in EMITTERS],
        "Total_cancelled" => [Emitters[Emitters[:,"Emitter_id"] .== e, "Captured_CO2_1_tCO2ptpa"][1]*(1- cc_emitter_extract[e]) *TOT_production[e] for e in EMITTERS],
        "Total_capture_potential" => [Emitters[Emitters[:,"Emitter_id"] .== e, "Captured_CO2_1_tCO2ptpa"][1].*TOT_production[e] for e in EMITTERS]
    )


    Cluster_capture_summary = combine(
    DataFrames.groupby(Emitters_capture_info, :Cluster_julia),
    :Total_Mtpa_bio => sum,
    :Total_Mtpa_fossil => sum,
    :Total_cancelled => sum,
    :Total_capture_potential => sum
    )
    Lat_cluster = [Clusters[Clusters[:,"Cluster"]  .== c, "Lat"][1] for c in Cluster_capture_summary[:,"Cluster_julia"]]
    Lon_cluster = [Clusters[Clusters[:,"Cluster"]  .== c, "Lon"][1] for c in Cluster_capture_summary[:,"Cluster_julia"]]
    Cluster_capture_summary[:, "Lat"] = Lat_cluster
    Cluster_capture_summary[:, "Lon"] = Lon_cluster

    max_cap  =  20.0 #maximum(Cluster_capture_summary[!,"Total_capture_potential_sum"])
    size_scale = 0.2  # you can adjust this to control absolute pie size
    base_size = 600


     # storages 
    Storage_summary_df = storage_results_extract(Scenario_name::String, Subcase_name::String, CO2_tax::Int64)
    for i in 1:nrow(Storage_summary_df)
        lon = Storage_summary_df.Lon[i]
        lat = Storage_summary_df.Lat[i]
        
        Full = Storage_summary_df.Stored_vol_node_origin[i]
        Empty = Storage_summary_df.Theoretical_volume_mt[i]./Storage_periods - Storage_summary_df.Stored_vol_node_origin[i]
        sizes = [Full, Empty]
        total = sum(sizes)
        if total == 0
            continue  # skip empty pies
        end

        # Compute pie size (relative to total)
        pie_radius = size_scale * sqrt(total / max_cap)

         size = base_size * (total / max_cap)

        # Call Python function
        colors_pie = ["grey", "white"]
        py"draw_pie"(sizes, lon, lat, size, ax, colors_pie)



        # # Create new inset axes at cluster location
        # bbox = [lon - pie_radius, lat - pie_radius, 2*pie_radius, 2*pie_radius]
        # inset_ax = fig.add_axes(bbox, transform=ax[2].transData, zorder=5)  # Data-coord inset
        # inset_ax.pie(sizes, colors=["green", "brown", "indianred"])
        # inset_ax.set_aspect("equal")
        # inset_ax.axis("off")
    end



    # ax[2].set_xlim([2,10])
    # ax[2].set_ylim([49,55])
    # ax[2].scatter(
    # Cluster_capture_summary.Lon, 
    # Cluster_capture_summary.Lat,
    # s=10,  # Hide points; just using coords for pie overlay
    # color = "gray")

    # Emitters
    for i in 1:nrow(Cluster_capture_summary)
        lon = Cluster_capture_summary.Lon[i]
        lat = Cluster_capture_summary.Lat[i]
        
        bio = Cluster_capture_summary.Total_Mtpa_bio_sum[i]
        fossil = Cluster_capture_summary.Total_Mtpa_fossil_sum[i]
        cancelled = Cluster_capture_summary.Total_cancelled_sum[i]
        
        sizes = [bio, fossil, cancelled]
        total = sum(sizes)
        if total == 0
            continue  # skip empty pies
        end

        # Compute pie size (relative to total)
        pie_radius = size_scale * sqrt(total / max_cap)

         size = base_size * (total / max_cap)

        # Call Python function
        colors_pie = ["darkgreen", "steelblue", "indianred"]
        py"draw_pie"(sizes, lon, lat, size, ax, colors_pie)



        # # Create new inset axes at cluster location
        # bbox = [lon - pie_radius, lat - pie_radius, 2*pie_radius, 2*pie_radius]
        # inset_ax = fig.add_axes(bbox, transform=ax[2].transData, zorder=5)  # Data-coord inset
        # inset_ax.pie(sizes, colors=["green", "brown", "indianred"])
        # inset_ax.set_aspect("equal")
        # inset_ax.axis("off")
    end

   
    # === 1. Capture volume (empty circles) ===
    legend_totals = [1.0, 5.0, 10.0, 20.0]  # MtCO₂
    volume_handles = [
        matplotlib_lines.Line2D(
            [], [], 
            marker="o", color="w", markeredgewidth = 0.5, 
            markeredgecolor="k", markerfacecolor="none", 
            markersize=sqrt(base_size * (val / max_cap)),
            label="$(round(val, digits=1)) MtCO2"
        )
        for val in legend_totals
    ]

    # === 2. Pie slice components (filled circles) ===
    colors_pie = ["darkgreen", "steelblue", "indianred"]
    bio_patch = matplotlib_patches.Circle((0, 0), radius=0.1, facecolor="darkgreen", label="Bio CO2 captured", alpha = 0.5)
    fossil_patch = matplotlib_patches.Circle((0, 0), radius=0.1, facecolor="steelblue", label="Fossil CO2 captured", alpha = 0.5)
    cancelled_patch = matplotlib_patches.Circle((0, 0), radius=0.1, facecolor="indianred", label="Cancelled sites", alpha = 0.5)
    storage_patch = matplotlib_patches.Circle((0, 0), radius=0.1, facecolor="gray", label="Storage volume", alpha = 0.5)

    for pipe in Pipe_coordinates
        plt.plot(
            [pipe[1,1], pipe[2,1]],
            [pipe[1,2], pipe[2,2]],
            "--",  # Dashed line for candidate connections
            color="dimgrey",
            alpha = 0.5, 
            linewidth=0.5,
            label="Candidate connection")
    end

    if CDR_effect == false
            # === 3. Combine and add legend to ax ===
        all_handles = vcat(volume_handles, [bio_patch, fossil_patch, cancelled_patch, storage_patch])
        if Legend == true
            ax.legend(
                handles=all_handles, 
                loc="upper right", 
                fontsize=8, 
                # title_fontsize=5,
                frameon=true)
        else 
            skip 
        end
    
    else

        # if MPEC .== true
        #     DF_sankey_Trilateral = sankey_2_scenario_change_py(results_industry_Trilateral_file_HPC, (Scenario_name_1 = "CDR_price"; Scenario_name_1), (Scenario_name_2 = "CDR_price"; Scenario_name_2), (Figure_name = "$(Region)_sankey_py"; Figure_name), (Plotting = false; Plotting))
        #     Fossil_CC_trans = DF_sankey_Trilateral[(DF_sankey_Trilateral[:, "Scenario_1"] .== "Fossil") .&& (DF_sankey_Trilateral[:, "Scenario_2"] .== "Bio + CCS"), :]
        #     CC_fossil_trans = DF_sankey_Trilateral[(DF_sankey_Trilateral[:, "Scenario_1"] .== "Fossil + CCS") .&& (DF_sankey_Trilateral[:, "Scenario_2"] .== "Electric"), :]
        # else
            DF_sankey_Trilateral = sankey_2_scenario_change_py((Scenario_name_1 = "No_CDR_price"; Scenario_name_1), (Scenario_name_2 = "CDR_price"; Scenario_name_2), (Plotting = false; Plotting))
            Fossil_CC_trans = DF_sankey_Trilateral[(DF_sankey_Trilateral[:, "Scenario_1"] .!= "Fossil + CCS") .&& (DF_sankey_Trilateral[:, "Scenario_2"] .== "Fossil + CCS"), :]
            CC_fossil_trans = DF_sankey_Trilateral[(DF_sankey_Trilateral[:, "Scenario_1"] .!= "Fossil") .&& (DF_sankey_Trilateral[:, "Scenario_2"] .== "Fossil"), :]
        # end
            Fossil_CC_trans = DF_sankey_Trilateral[(DF_sankey_Trilateral[:, "Scenario_1"] .!= "Fossil + CCS") .&& (DF_sankey_Trilateral[:, "Scenario_2"] .== "Fossil + CCS"), :]
            CC_fossil_trans = DF_sankey_Trilateral[(DF_sankey_Trilateral[:, "Scenario_1"] .!= "Electric") .&& (DF_sankey_Trilateral[:, "Scenario_2"] .== "Electric"), :]
    


            Fossil_CC_trans[:, "Lat"] = [Emitters[Emitters[:,"Emitter_id"] .== e, "Lat"][1] for e in Fossil_CC_trans[:,"Emitter_id"]]
            Fossil_CC_trans[:, "Lon"] = [Emitters[Emitters[:,"Emitter_id"] .== e, "Lon"][1] for e in Fossil_CC_trans[:,"Emitter_id"]]
            Fossil_CC_trans[:, "Captured_CO2_1_tCO2ptpa"] = [Emitters[Emitters[:,"Emitter_id"] .== e, "Captured_CO2_1_tCO2ptpa"][1] for e in Fossil_CC_trans[:,"Emitter_id"]]
            Fossil_CC_trans[:, "Sector_name"] = [Emitters[Emitters[:,"Emitter_id"] .== e, "Sector_name"][1] for e in Fossil_CC_trans[:,"Emitter_id"]]
            
            CC_fossil_trans[:, "Lat"] = [Emitters[Emitters[:,"Emitter_id"] .== e, "Lat"][1] for e in CC_fossil_trans[:,"Emitter_id"]]
            CC_fossil_trans[:, "Lon"] = [Emitters[Emitters[:,"Emitter_id"] .== e, "Lon"][1] for e in CC_fossil_trans[:,"Emitter_id"]]
            CC_fossil_trans[:, "Not_Captured_CO2_1_tCO2ptpa"] = [Emitters[Emitters[:,"Emitter_id"] .== e, "Captured_CO2_1_tCO2ptpa"][1] for e in CC_fossil_trans[:,"Emitter_id"]]
            CC_fossil_trans[:, "Sector_name"] = [Emitters[Emitters[:,"Emitter_id"] .== e, "Sector_name"][1] for e in CC_fossil_trans[:,"Emitter_id"]]


            Color_dict = Dict("Chemical" => "chocolate", "Fertilisers" => "goldenrod", "Refineries" => "darkred", "Cement" => "darkblue", "Steel" => "limegreen", "Glass" => "mediumvioletred")
            for e in 1:length(Fossil_CC_trans[:, "Emitter_id"])
                scatter = ax.scatter(
                    Fossil_CC_trans[e, "Lon"],
                    Fossil_CC_trans[e, "Lat"],
                    #label='Target Regions',
                    s = sqrt(base_size * (Fossil_CC_trans[e, "Captured_CO2_1_tCO2ptpa"] / (max_cap/50))), # changing size so that it is more clear where those are located
                    color=Color_dict[Fossil_CC_trans[e, "Sector_name"]],
                    marker = "*", 
                    edgecolors = "black", 
                    linewidth = 0.3
                )
            end 

            for e in 1:length(CC_fossil_trans[:, "Emitter_id"])
                scatter = ax.scatter(
                    CC_fossil_trans[e, "Lon"],
                    CC_fossil_trans[e, "Lat"],
                    #label='Target Regions',
                    s = sqrt(base_size * (CC_fossil_trans[e, "Not_Captured_CO2_1_tCO2ptpa"] /  (max_cap/50))),
                    color=Color_dict[CC_fossil_trans[e, "Sector_name"]],
                    marker = "^", 
                    edgecolors = "black", 
                    linewidth = 0.3
                )
            end 
            Markers_facilitation = Line2D([0], [0], marker="*", markeredgecolor = "black", lw=0, color="white",  label="Facilitated fossil CC sites (vs no CDR)")
            Markers_disfacilitation = Line2D([0], [0], marker="^", markeredgecolor = "black",  lw=0, color="white",  label="Cancelled fossil CC sites (vs no CDR)")

            all_handles = vcat(vcat(volume_handles, [bio_patch, fossil_patch, cancelled_patch, storage_patch]), [Markers_facilitation, Markers_disfacilitation])
            Handels_1 = vcat(volume_handles, [bio_patch, fossil_patch, cancelled_patch, storage_patch])
            Handels_2 =  [Markers_facilitation, Markers_disfacilitation]

            if Legend == true 
            legend1 = ax.legend(
                handles=Handels_1, 
                loc="upper right", 
                fontsize=8, 
                # title_fontsize=5,
                frameon=true)
            ax.add_artist(legend1)  # Keep this legend

            # Second legend (example handles)
            legend2 = ax.legend(
            handles=Handels_2,
            loc="center",
            bbox_to_anchor=(0.55, 0.01, 0.4, 0.15),
            fontsize=7.5,
            frameon=false
            )
            ax.add_artist(legend2)
            else 
                skip 
            end
        end




    
    # show plot 

    for i in 1:1

        ax.set_xlabel("Longitude")
        ax.set_ylabel("Latitude")

        # cbar = plt.colorbar(sm,ax =ax, label="CO2 network infrastructure",shrink=0.2)

        ax.spines["top"].set_visible(false)    # Remove top border
        ax.spines["right"].set_visible(false)  # Remove right border
        ax.spines["bottom"].set_visible(false) # Remove bottom border
        ax.spines["left"].set_visible(false)   # Remove left border

        ax.set_xlabel("")  # Remove X-axis title
        ax.set_ylabel("")  # Remove Y-axis title

        # Remove X-axis and Y-axis tick labels
        ax.set_xticks([])
        ax.set_yticks([])


        # Axis limits 
        ## Regional 
        if Region == "Trilateral"
            ax.set_xlim([1,11])
            ax.set_ylim([49.5,54.5])
        elseif Region == "Europe"
            ## European 
            ax.set_xlim([-10,25])
            ax.set_ylim([38,60])
        else 
            print("Error - region coordinates not defined")
        end

    end


    ####################################
    # Saving figure 
    ####################################

  

    plt.title("", pad=25,fontsize=14)
    # plt.tight_layout()
    if MPEC == true 
        save_path = "./Figures/MPEC/Pie_chart_$(Scenario_name)_$(Subcase_name).svg"
    elseif Social_decision == false 
        save_path = "./Figures/Max connectivity/Pie_chart_$(Scenario_name).svg"
    elseif Tariff == true 
        save_path = "./Figures/Tariff/Pie_chart_$(Scenario_name).svg"
    else
        save_path = "./Figures/Base/Pie_chart_$(Scenario_name).svg"
    end

    plt.savefig(save_path, bbox_inches="tight")


    return 
end


function visualisation_CDR_effect()




    # Plotting

    fig, ax = plt.subplots(1,3, figsize=(8, 8))
    # divider = make_axes_locatable(ax)
  


    if Region == "Trilateral"
        trilateral= py"geo_coverage"(NUTS_level=2,codes=["NL","BE","DEA"],shapefile =shapefile_eu)
        borders = py"geo_coverage"(NUTS_level=0,codes=["NL","BE","DEA"],shapefile =shapefile_eu)
        non_trilateral= py"geo_coverage"(NUTS_level=2,codes=["FR","DE"],shapefile =shapefile_eu)
        other_borders = py"geo_coverage"(NUTS_level=0,codes=["FR","DE"],shapefile =shapefile_eu)
        borders_NRW = py"geo_coverage"(NUTS_level=1,codes=["DEA"],shapefile =shapefile_eu)

        # Regions
        trilateral.boundary.plot(ax=ax[1], linewidth=0.2,color="black")
        borders.boundary.plot(ax=ax[1], linewidth=0.7,color="black")
        non_trilateral.boundary.plot(ax=ax[1], linewidth=0.2,color="grey")
        other_borders.boundary.plot(ax=ax[1], linewidth=0.3,color="grey")
        borders_NRW.boundary.plot(ax=ax[1], linewidth=0.7,color="black")

        trilateral.boundary.plot(ax=ax[2], linewidth=0.2,color="black")
        borders.boundary.plot(ax=ax[2], linewidth=0.7,color="black")
        non_trilateral.boundary.plot(ax=ax[2], linewidth=0.2,color="grey")
        other_borders.boundary.plot(ax=ax[2], linewidth=0.3,color="grey")
        borders_NRW.boundary.plot(ax=ax[2], linewidth=0.7,color="black")

        
        trilateral.boundary.plot(ax=ax[3], linewidth=0.2,color="black")
        borders.boundary.plot(ax=ax[3], linewidth=0.7,color="black")
        non_trilateral.boundary.plot(ax=ax[3], linewidth=0.2,color="grey")
        other_borders.boundary.plot(ax=ax[3], linewidth=0.3,color="grey")
        borders_NRW.boundary.plot(ax=ax[3], linewidth=0.7,color="black")

    elseif Region == "Europe"
        NUTS_ = gpd.read_file(shapefile_eu)
        non_trilateral= py"geo_coverage"(NUTS_level=2,codes=unique(NUTS_["CNTR_CODE"]),shapefile =shapefile_eu)
        other_borders = py"geo_coverage"(NUTS_level=0,codes=unique(NUTS_["CNTR_CODE"]),shapefile =shapefile_eu)

        non_trilateral.boundary.plot(ax=ax[1], linewidth=0.2,color="grey")
        other_borders.boundary.plot(ax=ax[1], linewidth=0.3,color="grey")

        non_trilateral.boundary.plot(ax=ax[2], linewidth=0.2,color="grey")
        other_borders.boundary.plot(ax=ax[2], linewidth=0.3,color="grey")

        non_trilateral.boundary.plot(ax=ax[3], linewidth=0.2,color="grey")
        other_borders.boundary.plot(ax=ax[3], linewidth=0.3,color="grey")

    else
    end



    capacity_cutout = 0.008
    cmap_style = "winter_r"
    v_min = 1
    v_max =  maximum(Pipes_opt_sizes) # 250

    #####################################
    # Subplot 1: lines and emitters 
    #####################################
    # Candidate Pipelines
        
    system_data_file =   eval(Symbol("system_data_file_", detail_level))
    Intercept = true  # True: binary variables for pipeline investments, false: no binary parameters for pipeline investments 
    global Costs, Routing_nodes_all, Pipelines_all, Terminals, Storage_offshore, Storage_inland, Offshore_nodes, Clusters = import_data_TandS(system_data_file) 
    include("parameters.jl")    # run all the parameters of the script 
    for pipe in Pipe_coordinates
        ax[1].plot(
            [pipe[1,1], pipe[2,1]],
            [pipe[1,2], pipe[2,2]],
            "--",  # Dashed line for candidate connections
            color="dimgrey",
            alpha = 0.5, 
            linewidth=0.5,
            label="Candidate connection")
    end

    triangle_marker = Line2D([0], [0], marker="^", color="w", label="Storage sites", markerfacecolor="brown", markersize=8)              
    dashed_line = Line2D([0], [0], linestyle="--", color="grey", lw=1.5, label="Candidate Connection")
    full_line = Line2D([0], [0], linestyle="-", color="mediumseagreen", lw=2, label="Selected Connection")
    capture_marker = Line2D([0], [0], marker="o", lw=0, alpha = 0.5,  color="mediumseagreen",  label="CCS participant")
    non_capture_marker = Line2D([0], [0], marker="o", lw=0, alpha = 0.5, color="indianred",  label="CCS nonparticipant")
    emitter_marker = Line2D([0], [0], marker=".", lw=0,  color="black", label="Non-CCS sites (default)")
    centroids = Line2D([0], [0], marker="x", lw=0,  color="dimgrey", label="Cluster centroids")
    terminal_marker = Line2D([0], [0], marker="s", lw=0,  color="grey", label="Terminal")
    # Optimal pipelines
    
    for index in 1:length(Pipes_opt_co_na)
        pipe_opt_coordinates = values.(Pipes_opt_co_na)[index][:]
        pipe_opt_cap = values.(Pipes_opt_sizes)[index]
        # arrow = FancyArrowPatch(
        #     (pipe_opt_coordinates[1], pipe_opt_coordinates[3]),
        #     (pipe_opt_coordinates[2], pipe_opt_coordinates[4]),
        #     arrowstyle="-",
        #     mutation_scale=20.0, # 12
        #     color=py"getattr"(plt.cm,cmap_style)(pipe_opt_cap / v_max),  # Use 'viridis_r' colormap
        #     alpha=0.7,
        #     lw=2 #,         transform=ax.transData,
        # )
        # ax.add_patch(arrow) #https://matplotlib.org/stable/api/_as_gen/matplotlib.patches.ConnectionStyle.html#matplotlib.patches.ConnectionStyle

   
    end

    all_pipe_opt_coordinates = values.(Pipes_opt_co_na)[:][:];
    all_pipe_opt_cap = values.(Pipes_opt_sizes)[:]
    indices_to_keep = findall(x -> x >= 0.0, all_pipe_opt_cap)
    filtered_pipe_opt_cap = all_pipe_opt_cap[indices_to_keep]
    filtered_pipe_opt_coordinates = all_pipe_opt_coordinates[indices_to_keep]
    segments = [[(filtered_pipe_opt_coordinates[i][1], filtered_pipe_opt_coordinates[i][3]), (filtered_pipe_opt_coordinates[i][2], filtered_pipe_opt_coordinates[i][4])] for i in 1:length(filtered_pipe_opt_coordinates)] 
    lc = LineCollection(segments, cmap=cmap_style, norm=plt.Normalize(vmin=0, vmax=v_max), alpha= 0.7, lw=1.5)
    lc.set_array(filtered_pipe_opt_cap)
    ax[1].add_collection(lc)

    cbar = plt.colorbar(lc,ax =ax[1], label="CO2 network infrastructure",shrink=0.2, legend = :bottomright)
    cbar.ax.set_ylabel("Pipe capacity (MtCO₂pa)",size=14)
    cbar.ax.yaxis.set_tick_params(labelsize=12)

    # Clusters 
    sm = plt.cm.ScalarMappable(cmap=cmap_style, norm=plt.Normalize(vmin=1, vmax=v_max))
    sm.set_array([])

    scatter_plot = ax[1].scatter(
        Cluster_coordinates[:,2],
        Cluster_coordinates[:,1],
        s=15,
        #label='Target Regions',
        marker = "x",
        lw=1.0,
        color="dimgrey"
    )

    scatter = ax[1].scatter(
        Terminal_coordinates[:,2],
        Terminal_coordinates[:,1],
        s=10,
        color="grey",
        marker="s",
    )
    Industry_connection_results = industry_results_extract(Scenario_name::String, Subcase_name::String, CO2_tax::Int64)
    cc_emitter_extract =  Dict(e => try Industry_connection_results[Industry_connection_results[:, "Emitters"] .== e, "Bin_connection"][1] catch skip end for e in EMITTERS)
    

    # Emitters 
    capture_volume_dict = Dict(e => TOT_capture_1_CO2[e].*cc_emitter_extract[e] for e in EMITTERS)
    Emitters_modelled = Dict(e =>  (Emitters[Emitters[:,"Emitter_id"] .==e, "Lon"][1],  Emitters[Emitters[:,"Emitter_id"] .==e, "Lat"][1]) for e in EMITTERS)
    # filtered_emitters = filter(kv -> kv[2] != (0, 0), Emitters_modelled)
    Emitters_captured = Dict(e => Emitters_modelled[e] for e in EMITTERS if cc_emitter_extract[e] != 0)
    Emitters_cancelled = Dict(e => Emitters_modelled[e] for e in EMITTERS if(cc_emitter_extract[e] == 0) &(TOT_capture_1_CO2[e] != 0))
    Emitters_cancelled_names = [Emitters[Emitters[:,"Emitter_id"] .==k, "Product_route_name"][1] for (k, v) in zip(keys(Emitters_cancelled),Emitters_cancelled)]
    Non_capture_sites = Dict(e => Emitters_modelled[e] for e in EMITTERS if TOT_capture_1_CO2[e] == 0)
    min_size = 1
    max_size = 30
    


    capture_volume_vect = [TOT_capture_1_CO2[e].*cc_emitter_extract[e] for e in EMITTERS]

    capture_volume_vect = [TOT_capture_1_CO2[e] for e in EMITTERS]
    normalised_cc_vol_vect = py"scale_capture_volume"(min_size,max_size,capture_volume_vect)
    normalised_cc_vol_dict = Dict(e => normalised_cc_vol_vect[i] for  (i,e) in enumerate(EMITTERS))

    #capture_volume_vect_cancelled = [TOT_capture_1_CO2[e].*(1-cc_emitter[e]) for e in EMITTERS]
    # normalised_cc_vol_vect_cancelled_with_NaN= py"scale_capture_volume"(min_size,max_size,capture_volume_vect_cancelled)
    # normalised_cc_vol_vect_cancelled = replace(normalised_cc_vol_vect_cancelled_with_NaN, NaN => 0.0)

    normalised_cc_vol_dict_cancelled = Dict(e => normalised_cc_vol_vect[i] for  (i,e) in enumerate(EMITTERS))

    # capturing emitters 
    # all emitters
    for e in 1:length(Emitters[:, "Emitter_id"])
        scatter = ax[1].scatter(
            Emitters[e, "Lon"],
            Emitters[e, "Lat"],
            #label='Target Regions',
            s = 0.5,
            color="black"
        )
    end 
    
    for e in EMITTERS
        try # Assigning green color to all connected carbon capture sites 
            scatter = ax[1].scatter(
                Emitters_captured[e][1],
                Emitters_captured[e][2],
                #label='Target Regions',
                s = 2,
                color="mediumseagreen"
            )
        catch 
        end
        try # Assigning green color size to all sites 
        scatter = ax[1].scatter(
            Emitters_captured[e][1],
            Emitters_captured[e][2],
            s=normalised_cc_vol_dict[e],
            #label='Target Regions',
            color="mediumseagreen",
            alpha= 0.5,
        )
        catch 
        end

        try # Assigning red color to all cancelled carbon capture sites 
            scatter = ax[1].scatter(
                Emitters_cancelled[e][1],
                Emitters_cancelled[e][2],
                #label='Target Regions',
                s = 2,
                color="indianred"
            )
        catch 
        end

        try # assigning red color to all disconnected carbon capture sites 
        scatter = ax[1].scatter(
            Emitters_cancelled[e][1],
            Emitters_cancelled[e][2],
            s=normalised_cc_vol_dict_cancelled[e],
            #label='Target Regions',
            color="indianred",
            alpha= 0.5,
        )
        # if e == "E2574"
        #      plt.annotate(e, (Emitters_cancelled[e][1], Emitters_cancelled[e][2]), textcoords = "offset points", xytext = (5,5), ha="center")
        # end
        catch 
        end

        try # assigning blue color to all no carbon capture sites
        scatter = ax[1].scatter(
            Non_capture_sites[e][1],
            Non_capture_sites[e][2],
            s= 2,
            #label='Target Regions',
            color="black",
            alpha= 0.5,
        )
        catch 
        end
    end 

    # Storage locations
    scatter = ax[1].scatter(
        Storage_offshore_coordinates[:,2],
        Storage_offshore_coordinates[:,1],
        s=15,
        color="brown",
        marker="^",
    )

    scatter = ax[1].scatter(
        Storage_inland_coordinates[:,2],
        Storage_inland_coordinates[:,1],
        s=15,
        color="brown",
        marker="^",
    )




    ax[1].legend(handles=[triangle_marker,dashed_line, full_line, emitter_marker, capture_marker, non_capture_marker, centroids, terminal_marker], fontsize=5, loc="upper center", bbox_to_anchor=(0.5, -0.05))

    # Table_parameters = Key_output_df.Parameters
    # Table_values = Key_output_df.Values
    # Table_units = Key_output_df.Unit
    # Table_matrix = hcat(Table_parameters, Table_values, Table_units)
    # plt.table(cellText=Table_matrix, colLabels=["Parameter", "Value", "Unit"], loc="bottom", cellLoc="center")
    # plt.subplots_adjust(bottom=0.3)




    ##############################################"""
    # Subplot 2: pies 
    ################################################
    Emitters_capture_info = DataFrame(
        "Emitter_id" => [e for e in EMITTERS], 
        "Cluster_julia" => [Emitters[Emitters[:,"Emitter_id"] .== e, "Cluster_julia"][1] for e in EMITTERS], 
        "Total_Mtpa_bio" => [Emitters[Emitters[:,"Emitter_id"] .== e, "Capture_ofwhich_bio_1_tCO2ptpa"][1]* cc_emitter_extract[e] for e in EMITTERS],
        "Total_Mtpa_fossil" =>[(Emitters[Emitters[:,"Emitter_id"] .== e, "Captured_CO2_1_tCO2ptpa"][1] - Emitters[Emitters[:,"Emitter_id"] .== e, "Capture_ofwhich_bio_1_tCO2ptpa"][1]) * cc_emitter_extract[e] for e in EMITTERS],
        "Total_cancelled" => [Emitters[Emitters[:,"Emitter_id"] .== e, "Captured_CO2_1_tCO2ptpa"][1]*(1- cc_emitter_extract[e]) for e in EMITTERS],
        "Total_capture_potential" => [Emitters[Emitters[:,"Emitter_id"] .== e, "Captured_CO2_1_tCO2ptpa"][1] for e in EMITTERS]
    )


    Cluster_capture_summary = combine(
    DataFrames.groupby(Emitters_capture_info, :Cluster_julia),
    :Total_Mtpa_bio => sum,
    :Total_Mtpa_fossil => sum,
    :Total_cancelled => sum,
    :Total_capture_potential => sum
    )
    Lat_cluster = [Clusters[Clusters[:,"Cluster"]  .== c, "Lat"][1] for c in Cluster_capture_summary[:,"Cluster_julia"]]
    Lon_cluster = [Clusters[Clusters[:,"Cluster"]  .== c, "Lon"][1] for c in Cluster_capture_summary[:,"Cluster_julia"]]
    Cluster_capture_summary[:, "Lat"] = Lat_cluster
    Cluster_capture_summary[:, "Lon"] = Lon_cluster

    max_cap  = maximum(Cluster_capture_summary[!,"Total_capture_potential_sum"])
    size_scale = 0.2  # you can adjust this to control absolute pie size

    # ax[2].set_xlim([2,10])
    # ax[2].set_ylim([49,55])
    # ax[2].scatter(
    # Cluster_capture_summary.Lon, 
    # Cluster_capture_summary.Lat,
    # s=10,  # Hide points; just using coords for pie overlay
    # color = "gray")
    base_size = 100
    for i in 1:nrow(Cluster_capture_summary)
        lon = Cluster_capture_summary.Lon[i]
        lat = Cluster_capture_summary.Lat[i]
        
        bio = Cluster_capture_summary.Total_Mtpa_bio_sum[i]
        fossil = Cluster_capture_summary.Total_Mtpa_fossil_sum[i]
        cancelled = Cluster_capture_summary.Total_cancelled_sum[i]
        
        sizes = [bio, fossil, cancelled]
        total = sum(sizes)
        if total == 0
            continue  # skip empty pies
        end

        # Compute pie size (relative to total)
        pie_radius = size_scale * sqrt(total / max_cap)

         size = base_size * (total / max_cap)

        # Call Python function
        colors_pie = ["darkgreen", "steelblue", "indianred"]
        py"draw_pie"(sizes, lon, lat, size, ax[2], colors_pie)

        # # Create new inset axes at cluster location
        # bbox = [lon - pie_radius, lat - pie_radius, 2*pie_radius, 2*pie_radius]
        # inset_ax = fig.add_axes(bbox, transform=ax[2].transData, zorder=5)  # Data-coord inset
        # inset_ax.pie(sizes, colors=["green", "brown", "indianred"])
        # inset_ax.set_aspect("equal")
        # inset_ax.axis("off")
    end

    # for i in 1:nrow(Cluster_capture_summary)
    #     pie_data = [
    #         Cluster_capture_summary.Total_Mtpa_bio_sum[i],
    #         Cluster_capture_summary.Total_Mtpa_fossil_sum[i],
    #         Cluster_capture_summary.Total_cancelled_sum[i]
    #     ]
    #     pie_labels = ["Bio", "Fossil", "Cancelled"]
    #     mycolors = ["green", "brown", "red"]

    #     # Generate the small pie chart
    #     p = ax[2].pie(pie_data, startangle = 90, colors = mycolors)  # small size
    # end

    # === 1. Capture volume (empty circles) ===
    legend_totals = [1.0, 5.0, 10.0, 20.0]  # MtCO₂
    volume_handles = [
        matplotlib_lines.Line2D(
            [], [], 
            marker="o", color="w", 
            markeredgecolor="k", markerfacecolor="none", 
            markersize=sqrt(base_size * (val / max_cap)),
            label="$(round(val, digits=1)) MtCO2"
        )
        for val in legend_totals
        ]
        # === 2. Pie slice components (filled circles) ===
        colors_pie = ["darkgreen", "steelblue", "indianred"]
        bio_patch = matplotlib_patches.Circle((0, 0), radius=0.1, facecolor="darkgreen", label="Bio CO2 captured")
        fossil_patch = matplotlib_patches.Circle((0, 0), radius=0.1, facecolor="steelblue", label="Fossil CO2 captured")
        cancelled_patch = matplotlib_patches.Circle((0, 0), radius=0.1, facecolor="indianred", label="Cancelled sites")

        # === 3. Combine and add legend to ax[1] ===
        all_handles = vcat(volume_handles, [bio_patch, fossil_patch, cancelled_patch])
        ax[2].legend(
            handles=all_handles, 
            loc="upper center", 
            bbox_to_anchor=(0.5, -0.05), 
            fontsize=6, 
            title_fontsize=5,
            frameon=true)
    

    ####################################
    # Subplot 2
    ####################################



    DF_sankey_Trilateral = sankey_2_scenario_change_py(results_industry_Trilateral_file_HPC, (Scenario_name_1 = "No_CDR_price"; Scenario_name_1), (Scenario_name_2 = "CDR_price"; Scenario_name_2), (Figure_name = "$(Region)_sankey_py"; Figure_name), (Plotting = false; Plotting))
    DF_sankey_Trilateral[(DF_sankey_Trilateral[:, "Scenario_1"] .!= "Fossil + CCS") .&& (DF_sankey_Trilateral[:, "Scenario_2"] .== "Fossil + CCS"), :]
    DF_sankey_Trilateral[(DF_sankey_Trilateral[:, "Scenario_1"] .!= "Fossil") .&& (DF_sankey_Trilateral[:, "Scenario_2"] .== "Fossil"), :]




    
    # show plot 

    for i in 1:3

        ax[i].set_xlabel("Longitude")
        ax[i].set_ylabel("Latitude")

        # cbar = plt.colorbar(sm,ax[1] =ax[1], label="CO2 network infrastructure",shrink=0.2)

        ax[i].spines["top"].set_visible(false)    # Remove top border
        ax[i].spines["right"].set_visible(false)  # Remove right border
        ax[i].spines["bottom"].set_visible(false) # Remove bottom border
        ax[i].spines["left"].set_visible(false)   # Remove left border

        ax[i].set_xlabel("")  # Remove X-ax[1]is title
        ax[i].set_ylabel("")  # Remove Y-ax[1]is title

        # Remove X-ax[1]is and Y-ax[1]is tick labels
        ax[i].set_xticks([])
        ax[i].set_yticks([])


        # Axis limits 
        ## Regional 
        if Region == "Trilateral"
            ax[i].set_xlim([1,11])
            ax[i].set_ylim([48,55])
        elseif Region == "Europe"
            ## European 
            ax[i].set_xlim([-10,25])
            ax[i].set_ylim([38,60])
        else 
            print("Error - region coordinates not defined")
        end

    end


    ####################################
    # Saving figure 
    ####################################

  

    plt.title("", pad=25,fontsize=14)
    # plt.tight_layout()
    if MPEC == true 
        save_path = "./Figures/MPEC/$(Scenario_name)_$(Subcase_name)_CDR.svg"
    elseif Social_decision == false 
        save_path = "./Figures/Max connectivity/$(Scenario_name)_$(Subcase_name)_CDR.svg"
    elseif Tariff == true 
        save_path = "./Figures/Tariff/$(Scenario_name)_$(Subcase_name)_CDR.svg"
    else
        save_path = "./Figures/Base/$(Scenario_name)_$(Subcase_name)_CDR.svg"
    end

    plt.savefig(save_path, bbox_inches="tight")





return 

end



function visualisation_pipes_FR(shapefile_eu, Scenario_name, Scenario_horizon)


    # Plotting

    fig, ax = plt.subplots(figsize=(8, 16))
    divider = make_axes_locatable(ax)
    

    if Region == "Trilateral"
        trilateral= py"geo_coverage"(NUTS_level=2,codes=["NL","BE","DEA","FRE1","FRE2"],shapefile =shapefile_eu)
        borders = py"geo_coverage"(NUTS_level=0,codes=["NL","BE","DEA","FRE1","FRE2"],shapefile =shapefile_eu)
        non_trilateral= py"geo_coverage"(NUTS_level=2,codes=["FR","DE"],shapefile =shapefile_eu)
        non_trilateral_2= py"geo_coverage"(NUTS_level=2,codes=["FR","DE", "NO", "SE", "DK", "LU"],shapefile =shapefile_eu)
        other_borders = py"geo_coverage"(NUTS_level=0,codes=["FR","DE", "NO", "DK", "SE"],shapefile =shapefile_eu)
        borders_NRW = py"geo_coverage"(NUTS_level=1,codes=["DEA", "FRE"],shapefile =shapefile_eu)

        # Regions
        # trilateral.boundary.plot(ax=ax, linewidth=0.2,color="black") # no provinces
        non_trilateral_2.plot(ax=ax, color="whitesmoke", edgecolor="none", zorder=0)
        borders_NRW.plot(ax=ax, color="white", edgecolor="none", zorder=0)

        borders.boundary.plot(ax=ax, linewidth=0.7,color="black")
        # non_trilateral.boundary.plot(ax=ax, linewidth=0.2,color="grey")
        other_borders.boundary.plot(ax=ax, linewidth=0.3,color="grey")
        borders_NRW.boundary.plot(ax=ax, linewidth=0.7,color="black")

    elseif Region == "Europe"
        NUTS_ = gpd.read_file(shapefile_eu)
        non_trilateral= py"geo_coverage"(NUTS_level=2,codes=unique(NUTS_["CNTR_CODE"]),shapefile =shapefile_eu)
        other_borders = py"geo_coverage"(NUTS_level=0,codes=unique(NUTS_["CNTR_CODE"]),shapefile =shapefile_eu)

        non_trilateral.boundary.plot(ax=ax, linewidth=0.2,color="grey")
        other_borders.boundary.plot(ax=ax, linewidth=0.3,color="grey")

    else
    end






    # Candidate Pipelines
        
    system_data_file =   eval(Symbol("system_data_file_", detail_level))
    Intercept = true  # True: binary variables for pipeline investments, false: no binary parameters for pipeline investments 
    global Costs, Routing_nodes_all, Pipelines_all, Terminals, Storage_offshore, Storage_inland, Offshore_nodes, Clusters = import_data_TandS(system_data_file) 
    include("parameters.jl")    # run all the parameters of the script 
    global Pipes_opt_co_na, Pipes_opt_sizes = pipeline_results_extract(Scenario_name::String, Subcase_name::String, CO2_tax::Int64)
    # scenario_title = Scenario_title_vect[i]
    global Industry_connection_results = industry_results_extract(Scenario_name::String, Subcase_name::String,CO2_tax)

    capacity_cutout = 0.008
    cmap_style = "winter_r"
    v_min = 1
    try 
        global v_max =  maximum(Pipes_opt_sizes) # 250
    catch 
        global v_max = v_min
    end


    for pipe in Pipe_coordinates
        plt.plot(
            [pipe[1,1], pipe[2,1]],
            [pipe[1,2], pipe[2,2]],
            "--",  # Dashed line for candidate connections
            color="dimgrey",
            alpha = 0.5, 
            linewidth=0.5,
            label="Candidate connection")
    end

    triangle_marker = Line2D([0], [0], marker="^", color="w", label="Storage sites", markerfacecolor="brown", markersize=8)  # need to use some mathmode otherwise italic text            
    Storage_capacity_marker = Line2D([0], [0], marker="o", lw=0,  color="grey", label="Storage capacity filled")
    dashed_line = Line2D([0], [0], linestyle="--", color="grey", lw=1.5, label="Candidate connections")
    full_line = Line2D([0], [0], linestyle="-", color="mediumseagreen", lw=2, label="Selected connection")
    capture_marker = Line2D([0], [0], marker="o", lw=0, alpha = 0.5,  color="mediumseagreen",  label="CCS participant")
    non_capture_marker = Line2D([0], [0], marker="o", lw=0, alpha = 0.5, color="indianred",  label="CCS nonparticipant")
    emitter_marker = Line2D([0], [0], marker=".", lw=0,  color="black", label="Non-CCS sites (default)")
    centroids = Line2D([0], [0], marker="x", lw=0,  color="dimgrey", label="Cluster centroids")
    terminal_marker = Line2D([0], [0], marker="s", lw=0,  color="grey", label="Terminals")
    # Optimal pipelines
    
    for index in 1:length(Pipes_opt_co_na)
        pipe_opt_coordinates = values.(Pipes_opt_co_na)[index][:]
        pipe_opt_cap = values.(Pipes_opt_sizes)[index]
        # arrow = FancyArrowPatch(
        #     (pipe_opt_coordinates[1], pipe_opt_coordinates[3]),
        #     (pipe_opt_coordinates[2], pipe_opt_coordinates[4]),
        #     arrowstyle="-",
        #     mutation_scale=20.0, # 12
        #     color=py"getattr"(plt.cm,cmap_style)(pipe_opt_cap / v_max),  # Use 'viridis_r' colormap
        #     alpha=0.7,
        #     lw=2 #,         transform=ax.transData,
        # )
        # ax.add_patch(arrow) #https://matplotlib.org/stable/api/_as_gen/matplotlib.patches.ConnectionStyle.html#matplotlib.patches.ConnectionStyle

   
    end

    all_pipe_opt_coordinates = values.(Pipes_opt_co_na)[:][:];
    all_pipe_opt_cap = values.(Pipes_opt_sizes)[:]
    indices_to_keep = findall(x -> x >= 0.0, all_pipe_opt_cap)
    filtered_pipe_opt_cap = all_pipe_opt_cap[indices_to_keep]
    filtered_pipe_opt_coordinates = all_pipe_opt_coordinates[indices_to_keep]
    segments = [[(filtered_pipe_opt_coordinates[i][1], filtered_pipe_opt_coordinates[i][3]), (filtered_pipe_opt_coordinates[i][2], filtered_pipe_opt_coordinates[i][4])] for i in 1:length(filtered_pipe_opt_coordinates)] 
    lc = LineCollection(segments, cmap=cmap_style, norm=plt.Normalize(vmin=0, vmax=v_max), alpha= 0.7, lw=1.5, capstyle="round",   # rounded line ends
    joinstyle="round"   # rounded corners where segments meet
    )
    lc.set_array(filtered_pipe_opt_cap)
    ax.add_collection(lc)

    cbar = plt.colorbar(lc,ax =ax, label="CO2 network infrastructure",shrink=0.2)
    #cbar.ax.set_ylabel("Pipe capacity (MtCO2pa)",size=8)
    cbar.ax.set_ylabel(L"Pipe capacity (MtCO$_2$pa)", size=12)
    cbar.ax.yaxis.set_tick_params(labelsize=12)

    # Clusters 
    sm = plt.cm.ScalarMappable(cmap=cmap_style, norm=plt.Normalize(vmin=1, vmax=v_max))
    sm.set_array([])

    Trilateral_area = trilateral["geometry"]
    inside = [any(geom.contains(shpgeo.Point(row.Lon, row.Lat)) for geom in Trilateral_area)
    for row in eachrow(Cluster_coordinates_plot)]
    Clusters_inside = Cluster_coordinates_plot[inside, :]

    scatter_plot = plt.scatter(
        Clusters_inside[:,2],
        Clusters_inside[:,1],
        s=15,
        #label='Target Regions',
        marker = "x",
        lw=1.0,
        color="dimgrey"
    )

    scatter = plt.scatter(
        Terminal_coordinates[:,2],
        Terminal_coordinates[:,1],
        s=10,
        color="grey",
        marker="s",
    )
    Industry_connection_results = industry_results_extract(Scenario_name::String, Subcase_name::String, CO2_tax)
    cc_emitter_extract =  Dict(e => try Industry_connection_results[Industry_connection_results[:, "Emitters"] .== e, "Bin_connection"][1] catch skip end for e in EMITTERS)
    

    # Emitters 
    capture_volume_dict = Dict(e => TOT_capture_1_CO2[e].*cc_emitter_extract[e] for e in EMITTERS)
    Emitters_modelled = Dict(e =>  (Emitters[Emitters[:,"Emitter_id"] .==e, "Lon"][1],  Emitters[Emitters[:,"Emitter_id"] .==e, "Lat"][1]) for e in EMITTERS)
    # filtered_emitters = filter(kv -> kv[2] != (0, 0), Emitters_modelled)
    Emitters_captured = Dict(e => Emitters_modelled[e] for e in EMITTERS if cc_emitter_extract[e] != 0)
    Emitters_cancelled = Dict(e => Emitters_modelled[e] for e in EMITTERS if(cc_emitter_extract[e] == 0) &(TOT_capture_1_CO2[e] != 0))
    Emitters_cancelled_names = [Emitters[Emitters[:,"Emitter_id"] .==k, "Product_route_name"][1] for (k, v) in zip(keys(Emitters_cancelled),Emitters_cancelled)]
    Non_capture_sites = Dict(e => Emitters_modelled[e] for e in EMITTERS if TOT_capture_1_CO2[e] == 0)

    


    # capture_volume_vect = [TOT_capture_1_CO2[e].*cc_emitter_extract[e] for e in EMITTERS]

    capture_volume_vect = [TOT_capture_1_CO2[e] for e in EMITTERS] 
    min_size = 1
    max_size = 30 * maximum(capture_volume_vect)
    normalised_cc_vol_vect = py"scale_capture_volume"(min_size,max_size,capture_volume_vect)
    normalised_cc_vol_dict = Dict(e => normalised_cc_vol_vect[i] for  (i,e) in enumerate(EMITTERS))

    #capture_volume_vect_cancelled = [TOT_capture_1_CO2[e].*(1-cc_emitter[e]) for e in EMITTERS]
    # normalised_cc_vol_vect_cancelled_with_NaN= py"scale_capture_volume"(min_size,max_size,capture_volume_vect_cancelled)
    # normalised_cc_vol_vect_cancelled = replace(normalised_cc_vol_vect_cancelled_with_NaN, NaN => 0.0)

    normalised_cc_vol_dict_cancelled = Dict(e => normalised_cc_vol_vect[i] for  (i,e) in enumerate(EMITTERS))



    # capturing emitters 
    # all emitters
    # for e in 1:length(Emitters[:, "Emitter_id"])
    #     scatter = plt.scatter(
    #         Emitters[e, "Lon"],
    #         Emitters[e, "Lat"],
    #         #label='Target Regions',
    #         s = 0.5,
    #         color="black"
    #     )
    # end 

    
    for e in EMITTERS
        try # All emitters trilateral region
            scatter = plt.scatter(
                Emitters[e][1],
                Emitters[e][2],
                #label='Target Regions',
                s = 0.5,
                color="black"
            )
        catch 
        end
        try # Assigning green color to all connected carbon capture sites 
            scatter = plt.scatter(
                Emitters_captured[e][1],
                Emitters_captured[e][2],
                #label='Target Regions',
                s = 2,
                color="mediumseagreen"
            )
        catch 
        end
        try # Assigning green color size to all sites 
        scatter = plt.scatter(
            Emitters_captured[e][1],
            Emitters_captured[e][2],
            s=normalised_cc_vol_dict[e],
            #label='Target Regions',
            color="mediumseagreen",
            alpha= 0.5,
        )
        catch 
        end

    end
    for e in EMITTERS
        try # Assigning red color to all cancelled carbon capture sites 
            scatter = plt.scatter(
                Emitters_cancelled[e][1],
                Emitters_cancelled[e][2],
                #label='Target Regions',
                s = 2,
                color="indianred"
            )
        catch 
        end

        try # assigning red color to all disconnected carbon capture sites 
        scatter = plt.scatter(
            Emitters_cancelled[e][1],
            Emitters_cancelled[e][2],
            s=normalised_cc_vol_dict_cancelled[e],
            #label='Target Regions',
            color="indianred",
            alpha= 0.5,
        )
        # if e == "E2574"
        #      plt.annotate(e, (Emitters_cancelled[e][1], Emitters_cancelled[e][2]), textcoords = "offset points", xytext = (5,5), ha="center")
        # end
        catch 
        end

        try # assigning blue color to all no carbon capture sites
        scatter = plt.scatter(
            Non_capture_sites[e][1],
            Non_capture_sites[e][2],
            s= 2,
            #label='Target Regions',
            color="black",
            alpha= 0.5,
        )
        catch 
        end
    end 

    # Storage locations
    # scatter = plt.scatter(
    #     Storage_offshore_coordinates[:,2],
    #     Storage_offshore_coordinates[:,1],
    #     s=15,
    #     color="brown",
    #     marker="^",
    # )

    # scatter = plt.scatter(
    #     Storage_inland_coordinates[:,2],
    #     Storage_inland_coordinates[:,1],
    #     s=15,
    #     color="brown",
    #     marker="^",
    # )



    # storages 
    max_cap  =  20.0 #maximum(Cluster_capture_summary[!,"Total_capture_potential_sum"])
    size_scale = 0.2  # you can adjust this to control absolute pie size
    base_size = 600
    Storage_summary_df = storage_results_extract(Scenario_name::String, Subcase_name::String, CO2_tax)
    for i in 1:nrow(Storage_summary_df)
        lon = Storage_summary_df.Lon[i]
        lat = Storage_summary_df.Lat[i]
        
        Full = Storage_summary_df.Stored_vol_node_origin[i]
        Empty = Storage_summary_df.Theoretical_volume_mt[i]./Storage_periods - Storage_summary_df.Stored_vol_node_origin[i]
        sizes = [Full, Empty]
        total = sum(sizes)
        if total == 0
            continue  # skip empty pies
        end


        # Compute pie size (relative to total)
        pie_radius = size_scale * sqrt(total / max_cap)

         size = base_size * (total / max_cap)

        # Call Python function
        colors_pie = ["grey", "white"]
        py"draw_pie"(sizes, lon, lat, size, ax, colors_pie)



        # # Create new inset axes at cluster location
        # bbox = [lon - pie_radius, lat - pie_radius, 2*pie_radius, 2*pie_radius]
        # inset_ax = fig.add_axes(bbox, transform=ax[2].transData, zorder=5)  # Data-coord inset
        # inset_ax.pie(sizes, colors=["green", "brown", "indianred"])
        # inset_ax.set_aspect("equal")
        # inset_ax.axis("off")
    end


    # show plot 


    ax.set_xlabel("Longitude")
    ax.set_ylabel("Latitude")

    # cbar = plt.colorbar(sm,ax =ax, label="CO2 network infrastructure",shrink=0.2)

    ax.spines["top"].set_visible(false)    # Remove top border
    ax.spines["right"].set_visible(false)  # Remove right border
    ax.spines["bottom"].set_visible(false) # Remove bottom border
    ax.spines["left"].set_visible(false)   # Remove left border

    ax.set_xlabel("")  # Remove X-axis title
    ax.set_ylabel("")  # Remove Y-axis title

    # Remove X-axis and Y-axis tick labels
    ax.set_xticks([])
    ax.set_yticks([])


    # Axis limits 
    ## Regional 
    if Region == "Trilateral"
        # ax.set_xlim([1,11])
        # ax.set_ylim([48,60])
        if (Scenario_name == "Exit" || Scenario_name == "Exit_no_CDR") && Social_decision == true 
            ax.set_xlim([1,11])
            ax.set_ylim([49,57])
        elseif Social_decision == false 
            ax.set_xlim([1,11])
            ax.set_ylim([48,61])
        else
            ax.set_xlim([0,11])
            ax.set_ylim([49,61])
        end
    elseif Region == "Europe"
        ## European 
        ax.set_xlim([-10,25])
        ax.set_ylim([38,60])
    else 
        print("Error - region coordinates not defined")
    end


    # Remove X-axis and Y-axis tick marks (grid lines)
    ax.tick_params(axis="both", which="both", length=0)
    if Social_decision == true
        additional_title_info = "CC, T&S optimised"
    else
        additional_title_info = "CC max, T&S optimised"
    end
    plt.legend(handles=[dashed_line, full_line, emitter_marker, capture_marker, non_capture_marker, centroids, terminal_marker, Storage_capacity_marker], title_fontsize=6.5, fontsize=15, loc="upper right") #bbox_to_anchor=(0.55,0)

    # Table_parameters = Key_output_df.Parameters
    # Table_values = Key_output_df.Values
    # Table_units = Key_output_df.Unit
    # Table_matrix = hcat(Table_parameters, Table_values, Table_units)
    # plt.table(cellText=Table_matrix, colLabels=["Parameter", "Value", "Unit"], loc="bottom", cellLoc="center")
    # plt.subplots_adjust(bottom=0.3)

    plt.title("", pad=25,fontsize=14)
    plt.tight_layout()
    if MPEC == true 
        save_path = "./Figures/MPEC/$(Scenario_name)_$(CO2_tax)_$(Subcase_name).svg"
    else
        save_path = "./Figures/Base/$(Scenario_name)_$(CO2_tax)_$(Subcase_name).svg"
    end

    plt.savefig(save_path, bbox_inches="tight")




    # plt.show()
return     # plt.show()
end
