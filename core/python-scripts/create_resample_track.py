import reapy

from custom_errors import ResampleError
from helpers import create_new_rsmpl_track, save_resample_track, get_selected_track


@reapy.inside_reaper()
def main():
    try:
        project = reapy.Project()
        sel_track = get_selected_track(project)
        rsmpl_track = create_new_rsmpl_track(project, sel_track)
        save_resample_track(project, sel_track, rsmpl_track)
    except ResampleError as e:
        reapy.show_message_box(str(e))


if __name__ == '__main__':
    main()
