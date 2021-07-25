import reapy

from custom_errors import ResampleError
import helpers as hlp


@reapy.inside_reaper()
def main():
    try:
        project = reapy.Project(0)
        sel_track = hlp.get_selected_track(project)
        rsmpl_track = hlp.get_resample_track_by_source_track(project, sel_track)
        if rsmpl_track is not None:
            reapy.show_message_box(title=rsmpl_track.name, text=f'Track is already associated to a resample track')
            return
        if not hlp.track_has_instrument(sel_track):
            reapy.show_message_box(title=sel_track.name, text=f'Track has no instrument')
            return
        rsmpl_track = hlp.create_new_rsmpl_track(project, sel_track, delete_fx=False)
        hlp.save_resample_track(project, sel_track, rsmpl_track)
    except ResampleError as e:
        reapy.show_message_box(str(e))


if __name__ == '__main__':
    main()
