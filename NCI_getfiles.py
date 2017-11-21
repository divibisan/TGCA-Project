import requests
import json
import sys


def main():
    cases_endpt = 'https://api.gdc.cancer.gov/cases'
    projects_endpt = 'https://api.gdc.cancer.gov/projects'
    files_endpt = 'https://api.gdc.cancer.gov/files'
    data_endpt = 'https://api.gdc.cancer.gov/legacy/data'

    disease_name = "Skin Cutaneous Melanoma"
    program_name = "TCGA"

    #####################
    # GET DISEASE CASES #

    case_count = 1000
    filters = op_and([op_equals("project.name", disease_name),
                      op_equals("project.program.name", program_name)
                      ])
    params = {
        'filters': json.dumps(filters),
        'size': case_count,
        'fields': 'id,'
                  'case_id,'
                  'submitter_id,'
                  'demographic.gender,'
                  'diagnoses.vital_status,'
                  'diagnoses.days_to_death,'
                  'project.name,'
                  'sample_ids,'

    }

    response = requests.get(cases_endpt, params=params)

    cases = get_values(response, "id", ["diagnoses.vital_status",
                                        "diagnoses.days_to_death",
                                        "sample_ids",
                                        "case_id"])

    ##################################
    # GET FPKM FILES FOR THOSE CASES #
    filters = op_and([op_equals("data_category", "Transcriptome Profiling"),
                      op_equals("analysis.workflow_type", "HTSeq - FPKM"),
                      op_in("cases.case_id", list(cases.keys()))
                      ])
    params = {
        'filters': json.dumps(filters),
        'size': 3,
        'fields': 'cases.case_id,'
                  'cases.diagnoses.days_to_death,'
                  'cases.diagnoses.vital_status,'
                  'cases.samples.sample_type,'
                  'cases.demographic.gender,'
                  'file_name'}

    response = requests.post(files_endpt, data=params)

    file_ids = get_values(response, "id")

    files = get_values(response, "file_name",
                       ["cases.case_id",
                        "cases.diagnoses.days_to_death",
                        "cases.diagnoses.vital_status",
                        "cases.samples.sample_type",
                        "cases.demographic.gender"])

    #########################################################
    # Output list of file IDs in JSON to STDOUT to download #

    json.dump({"ids": file_ids}, sys.stdout)

    with open("files.txt", "w") as file:
        json.dump(files, file)


def op_equals(field, value):
    out = {"op": "=",
           "content": {"field": field, "value": [value]}}
    return out


def op_and(content):
    out = {"op": "and",
           "content": content}
    return out


def op_in(field, value):
    out = {"op": "in",
           "content": {"field": field, "value": value}}
    return out


def get_values(rsp, key, fields=[]):
    out = {}
    for hit in json.loads(rsp.content)["data"]["hits"]:
        hit_id = hit
        for k in key.split("."):
            hit_id = hit_id[k]
        out[hit_id] = {}
        for field in fields:
            hit_working = hit
            for f in field.split("."):
                hit_working = strip_list(hit_working)[f]
            out[hit_id][f] = hit_working
    if fields:
        return out
    else:
        return list(out.keys())


def strip_list(lst):
    if isinstance(lst, list):
        lst = lst[0]
    return lst


main()
